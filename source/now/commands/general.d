module now.commands.general;


import std.algorithm.mutation : stripRight;
import std.array;
import std.datetime;
import std.datetime.stopwatch : AutoStart, StopWatch;
import std.digest.md;
import std.file : read;
import std.random : uniform;
import std.stdio;
import std.string : toLower;
import std.uuid : sha1UUID, randomUUID;

import now.nodes;

import now.commands;
import now.grammar;

import now.commands.base64;
import now.commands.csv;
import now.commands.http;
import now.commands.iterators;
import now.commands.ini;
import now.commands.json;
import now.commands.markdown;
import now.commands.simpletemplate;
import now.commands.terminal;
import now.commands.tcp;
import now.commands.url;


static this()
{
    // alias Command = ExitCode function(string, Input, Output);

    // ---------------------------------------------
    // Native types, nodes and conversion

    /**
    Examples:
    ----------
    > type 1.2 | print
    float
    ----------
    */
    builtinCommands["type"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            output.push(item.type.to!string.toLower);
        }
        return ExitCode.Success;
    };
    builtinCommands["type.name"] = function(string path, Input input, Output output)
    {
        /*
        We can have types that behave like strings, for example, but
        are actually distinct from native strings, so it may be useful
        to see their actual name.

        > type.name $extraneous_type
        string_on_steroids
        */
        foreach (item; input.popAll)
        {
            output.push(item.typeName.to!string);
        }

        return ExitCode.Success;
    };
    /**
    Examples:
    ----------
    > methods 1
    (neq , <= , > , gt , to.char)
    ----------
    */
    builtinCommands["methods"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            String[] items = item.methods
                .keys
                .map!(x => new String(x))
                .array;
            auto list = new List(cast(Items)items);
            output.push(list);
        }
        return ExitCode.Success;
    };
    builtinCommands["commands"] = function(string path, Input input, Output output)
    {
        String[] items = builtinCommands
                .keys
                .map!(x => new String(x))
                .array;
        output.push(new List(cast(Items)items));
        return ExitCode.Success;
    };

    builtinCommands["to.string"] = function(string path, Input input, Output output)
    {
        foreach(item; input.popAll)
        {
            output.push(item.toString());
        }

        return ExitCode.Success;
    };
    builtinCommands["to.bool"] = function(string path, Input input, Output output)
    {
        foreach(item; input.popAll)
        {
            output.push(item.toBool());
        }
        return ExitCode.Success;
    };
    builtinCommands["to.integer"] = function(string path, Input input, Output output)
    {
        foreach(item; input.popAll)
        {
            output.push(item.toLong());
        }
        return ExitCode.Success;
    };
    builtinCommands["to.float"] = function(string path, Input input, Output output)
    {
        foreach(item; input.popAll)
        {
            output.push(item.toFloat());
        }
        return ExitCode.Success;
    };

    // ---------------------------------------------
    /**
    Returns the value of an object.
    ---
    > obj 123 | as x
    > print $x
    123
    ---
    > dict (k = v) | as dict
    > obj $dict : get k | print
    v
    ---
    */
    builtinCommands["obj"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            output.push(item);
        }
        return ExitCode.Success;
    };
    builtinCommands["o"] = builtinCommands["obj"];

    builtinCommands["collect"] = function(string path, Input input, Output output)
    {
        auto generatedOutput = new Output;

forLoop:
        foreach (generator; input.popAll)
        {
            auto range = generator.range();

            while (true)
            {
                // Reminder: `nextOutput` will be
                // truncated on each call to `next`.
                auto nextOutput = new Output;
                auto nextExitCode = range.next(input.escopo, nextOutput);
                generatedOutput.items ~= nextOutput.items;

                if (nextExitCode == ExitCode.Break)
                {
                    break forLoop;
                }
                else if (nextExitCode == ExitCode.Skip)
                {
                    continue;
                }
            }
        }
        output.push(new List(generatedOutput.items));
        return ExitCode.Success;
    };
    builtinCommands["sequence"] = function(string path, Input input, Output output)
    {
forLoop:
        foreach (generator; input.popAll)
        {
            if (generator.type == ObjectType.List)
            {
                auto list = cast(List)generator;
                output.push(list.items);
            }
            else
            {
                while (true)
                {
                    // Reminder: `nextOutput` will be
                    // truncated on each call to `next`.
                    auto nextOutput = new Output;
                    auto nextExitCode = generator.next(input.escopo, nextOutput);
                    output.push(nextOutput.items);

                    if (nextExitCode == ExitCode.Break)
                    {
                        break forLoop;
                    }
                    else if (nextExitCode == ExitCode.Skip)
                    {
                        continue;
                    }
                }
            }
        }
        return ExitCode.Success;
    };

    // ---------------------------------------------
    // Various ExitCodes:
    builtinCommands["break"] = function(string path, Input input, Output output)
    {
        return ExitCode.Break;
    };
    builtinCommands["continue"] = function(string path, Input input, Output output)
    {
        return ExitCode.Continue;
    };
    builtinCommands["skip"] = function(string path, Input input, Output output)
    {
        return ExitCode.Skip;
    };
    builtinCommands["return"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            if (item.type == ObjectType.Error)
            {
                auto erro = cast(Erro)item;
                if (erro.exception !is null)
                {
                    throw erro.exception;
                }
                else
                {
                    throw new NowException(
                        erro.escopo,
                        erro.message,
                        erro.subject,
                        erro.code
                    );
                }
            }
            output.push(item);
        }
        return ExitCode.Return;
    };

    // Scope
    /**
    ## Scopes

    When dealing with errors, at least we can see better names
    during long procedures. Good for test cases, too.

    Examples:
    ---
    > scope "send HTTP request" {
        http.get $url | as content
    }
    ---
    */

    builtinCommands["scope"] = function(string path, Input input, Output output)
    {
        auto name = input.pop!string;
        auto body = input.pop!SubProgram;

        auto newScope = input.escopo.addPathEntry(name);
        auto exitCode = body.run(newScope, output);
        return exitCode;
    };

    // ---------------------------------------------
    /**
    ## Text I/O
    */
    builtinCommands["print"] = function (string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            stdout.write(item);
        }
        if (path != "print.sameline")
        {
            stdout.writeln();
        }

        return ExitCode.Success;
    };

    /*
    ### Logging

    `log` will follow the specified format or "default".

    Examples:
    ---
    [logging/formats/default]
    include {
        - timestamp
        - hostname
    }

    get $program directory | as pd
    return '{"timestamp":$timestamp, "hostname":"$hostname", "path":$pd, "message":$message}'
    ---
    */
    builtinCommands["log"] = function(string path, Input input, Output output)
    {
        auto formatName = input.kwargs.require("format", new String("default")).toString;
        auto format = input.escopo.document.get!Dict(["logging", "formats", formatName], null);

        if (format is null)
        {
            foreach (item; input.popAll)
            {
                stderr.write(item.toString);
            }
            stderr.writeln;
        }
        else
        {
            auto body = format["body"];
            // TODO: parse the format at Program.initialize!
            auto parser = new NowParser(body.toString);
            auto subprogram = parser.consumeSubProgram;

            foreach (index, item; input.popAll)
            {
                auto newScope = input.escopo.addPathEntry(
                    "log/" ~ formatName ~ "/" ~ index.to!string
                );
                newScope["message"] = item;
                // A logger is not a handler, so we ignore the exitCode:
                // TODO: review this. Maybe we should take the exitCode
                // in consideration after all...
                subprogram.run(newScope, output);
            }
        }

        stderr.flush();

        return ExitCode.Success;
    };
    builtinCommands["print.sameline"] = builtinCommands["print"];

    /**
    Read the entire stdin.
    */
    builtinCommands["read"] = function(string path, Input input, Output output)
    {
        /*
        TODO:
        read | {print "stdin>"}
        read 4 | {print "fd4>"}
        */
        string content = stdin.byLine.join("\n").to!string;
        output.push(content);
        return ExitCode.Success;
    };
    builtinCommands["read.line"] = function(string path, Input input, Output output)
    {
        string content = stdin.readln.to!string;
        output.push(content);
        return ExitCode.Success;
    };
    builtinCommands["read.lines"] = function(string path, Input input, Output output)
    {
        output.push(new PathFileRange(stdin));
        return ExitCode.Success;
    };

    // ---------------------------------------------
    /**
    ## Time
    */
    builtinCommands["sleep"] = function(string path, Input input, Output output)
    {
        auto ms = input.pop!long;

        // TODO: why is that?
        // Probably a reminiscence from the times
        // we used to support FIBERS...
        auto sw = StopWatch(AutoStart.yes);
        while(true)
        {
            auto passed = sw.peek.total!"msecs";
            if (passed >= ms)
            {
                break;
            }
        }
        return ExitCode.Success;
    };
    builtinCommands["unixtime"] = function(string path, Input input, Output output)
    {
        SysTime today = Clock.currTime();
        long t = today.toUnixTime!long();
        log("- builtinCommands.unixtime.t:", t);
        output.push(cast(long)t);
        return ExitCode.Success;
    };

    builtinCommands["timer"] = function(string path, Input input, Output output)
    {
        /*
        scope "test the timer" {
            timer {
                sleep 5000
            } {
                print "This scope ran for $seconds seconds"
            }
        }
        # stderr> This scope ran for 5 seconds
        ---
        */
        auto subprogram = input.pop!SubProgram;
        auto callback = input.pop!SubProgram;

        auto sw = StopWatch(AutoStart.yes);
        auto exitCode = subprogram.run(input.escopo, output);
        sw.stop();

        auto seconds = sw.peek().total!"seconds";
        auto msecs = sw.peek().total!"msecs";
        auto usecs = sw.peek().total!"usecs";
        auto nsecs = sw.peek().total!"nsecs";

        auto newScope = input.escopo.addPathEntry("timer-callback");
        newScope["seconds"] = new Float(seconds);
        newScope["miliseconds"] = new Float(msecs);
        newScope["microseconds"] = new Float(usecs);
        newScope["nanoseconds"] = new Float(nsecs);

        // Run the callback, ignoring exit code:
        callback.run(newScope, output);
        return exitCode;
    };

    /**
    ## Errors
    */

    /*
    Signalize that an error occurred.

    ---
    > error "something wrong happened"
    ---

    It's a kind of equivalent to `return`,
    so no need to "return [error ...]". Just
    calling `error` will exit

    "Full" call:
    ---
    > error message code class
    > error "Not Found" 404 http
    > error "segmentation fault" 11 os
    ---
    */
    builtinCommands["error"] = function(string path, Input input, Output output)
    {
        string message = input.pop!string("An error ocurred");
        int code = cast(int)(input.pop!long(-1));
        // TODO: classe

        throw new UserException(
            input.escopo,
            message,
            code
        );
    };
    builtinCommands["switch"] = function(string path, Input input, Output output)
    {
        /*
        o 123
            | switch {type}
            ! integer {print "is an integer"}
            ! * {print "not an integer"}
        */
        auto body = input.pop!SubProgram;

        auto items = input.popAll;
        auto execOutput = new Output;
        auto exitCode = body.run(input.escopo, items, execOutput);
        auto eventName = execOutput.items[0].toString;
        throw new Event(input.escopo, eventName);
    };

    // ---------------------------------------------
    /**
    ## Debugging
    */

    /**
    Examples:
    ---
    > assert true
    > assert false
    assertion error: false
    ---
    > assert "this should be true" false
    assertion error: this should be true
    ---
    */
    builtinCommands["assert"] = function(string path, Input input, Output output)
    {
        string givenMessage = null;
        foreach (item; input.popAll)
        {
            if (item.type == ObjectType.String)
            {
                givenMessage = item.toString;
            }
            else if (!item.toBool())
            {
                auto msg = "assertion error";
                if (givenMessage !is null)
                {
                    msg ~= ": " ~  givenMessage;
                }
                throw new AssertionError(
                    input.escopo,
                    msg,
                    -1,
                    item
                );
            }
        }
        return ExitCode.Success;
    };
    /**
    Examples:
    ---
    [procedures/quit]
    parameters {
        code {
            type int
        }
    }

    [commands/run]
    parameters {}

    exit 10
    ---
    $ now ; echo $?
    10
    ---
    */
    builtinCommands["exit"] = function(string path, Input input, Output output)
    {
        int code = cast(int)(input.pop!long(0));
        auto message = input.pop!string("Process was stopped");

        if (code == 0)
        {
            // TODO: how to succesfully exit???
            return ExitCode.Return;
        }
        else
        {
            throw new UserException(
                input.escopo,
                message,
                code,
                null
            );
        }
    };

    // Names:
    /**
    Examples:
    ---
    > set a 1
    > print $a
    1
    ---
    */
    builtinCommands["set"] = function(string path, Input input, Output output)
    {
        auto key = input.pop!string(null);
        auto values = input.popAll();
        if (key is null || values.length == 0)
        {
            throw new SyntaxErrorException(
                input.escopo,
                "`" ~ path ~ "` must receive at least 2 arguments."
            );
        }
        else if (values.length == 1)
        {
            input.escopo[key] = values.front;
        }
        else
        {
            input.escopo[key] = values;
        }

        // Pass along the values, so we can use this:
        // > list 1 2 3 | as lista : length | print
        output.push(values);
        return ExitCode.Success;
    };
    builtinCommands["quickset"] = function(string path, Input input, Output output)
    {
        auto key = input.pop!string(null);
        auto value = input.pop!Item;
        input.escopo[key] = value;
        return ExitCode.Success;
    };
    builtinCommands["as"] = builtinCommands["set"];

    builtinCommands["discard"] = function(string path, Input input, Output output)
    {
        input.popAll;
        return ExitCode.Success;
    };
    builtinCommands["get"] = function(string path, Input input, Output output)
    {
        /*
        > set x 10
        > get x | print
        10
        */
        auto name = input.pop!string();
        output.push(input.escopo[name].evaluate(input.escopo));
        return ExitCode.Success;
    };
    builtinCommands["val"] = builtinCommands["get"];
    builtinCommands["vars"] = function(string path, Input input, Output output)
    {
        Items items;

        auto escopo = cast(Dict)(input.escopo);
        foreach (varName, _; escopo)
        {
            items ~= new String(varName);
        }
        escopo = cast(Dict)(input.escopo.document);
        foreach (varName, _; escopo)
        {
            items ~= new String(varName);
        }

        output.push(new List(items));
        return ExitCode.Success;
    };

    // TYPES
    builtinCommands["dict"] = function(string path, Input input, Output output)
    {
        /*
        > dict (a = 1) (b = 2) | as d
        > print ($d . a)
        1
        > print ($d . b)
        2
        */
        auto dict = new Dict();

        foreach(argument; input.popAll)
        {
            auto pair = cast(Pair)argument;
            if (pair.type != ObjectType.Pair)
            {
                throw new SyntaxErrorException(
                    input.escopo,
                    "`" ~ path ~ "` arguments should be Pairs."
                );
            }

            Item value = pair.items.back;
            pair.items.popBack();

            string key = pair.items.back.toString();
            pair.items.popBack();

            dict[key] = value;
        }
        output.push(dict);
        return ExitCode.Success;
    };
    builtinCommands["list"] = function(string path, Input input, Output output)
    {
        /*
        > set l [list 1 2 3 4]
        # l = (1 , 2 , 3 , 4)
        */
        output.push(new List(input.popAll));
        log("- builtinCommands.list.output:", output);
        return ExitCode.Success;
    };

    // set lista (a , b , c , d)
    // -> set lista [, a b c d]
    // --> set lista [list a b c d]
    builtinCommands[","] = builtinCommands["list"];

    // set pair (a = b)
    // -> set pair [= a b]
    builtinCommands["="] = function(string path, Input input, Output output)
    {
        auto key = input.pop!Item();
        auto value = input.pop!Item();
        Items rest = input.popAll();
        if (rest.length > 0)
        {
            throw new SyntaxErrorException(
                input.escopo,
                "Invalid syntax: Pairs should contain only 2 elements",
                -1,
                key
            );
        }
        output.push(new Pair([key, value]));
        return ExitCode.Success;
    };
    builtinCommands["path"] = function (string name, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            string path = item.toString;
            output.push(new Path(path));
        }
        return ExitCode.Success;
    };
    builtinCommands["http"] = function (string name, Input input, Output output)
    {
        auto hostname = input.pop!String();
        output.push(new Http(hostname));
        return ExitCode.Success;
    };

    // CONDITIONALS
    builtinCommands["if"] = function(string path, Input input, Output output)
    {
        auto condition = input.pop!bool;
        auto thenBody = input.pop!SubProgram;

        if (condition)
        {
            return thenBody.run(input.escopo, output);
        }
        else
        {
            auto elseBody = input.pop!SubProgram(null);
            if (elseBody !is null)
            {
                return elseBody.run(input.escopo, output);
            }
        }

        return ExitCode.Success;
    };

    builtinCommands["when"] = function(string path, Input input, Output output)
    {
        /*
        If first argument is true, executes the second one and return.
        */
        auto isConditionTrue = input.pop!bool;
        auto thenBody = input.pop!SubProgram;

        if (isConditionTrue)
        {
            auto exitCode = thenBody.run(input.escopo, output);
            if (exitCode == ExitCode.Success)
            {
                return ExitCode.Return;
            }
            else
            {
                return exitCode;
            }
        }
        return ExitCode.Success;
    };
    builtinCommands["default"] = function(string path, Input input, Output output)
    {
        /*
        Just like when, but there's no "first argument" to evaluate,
        it always executes the body and returns.
        */
        auto body = input.pop!SubProgram();
        auto exitCode = body.run(input.escopo, output);
        if (exitCode == ExitCode.Success)
        {
            return ExitCode.Return;
        }
        else
        {
            return exitCode;
        }
    };

    // ITERATORS
    builtinCommands["transform"] = function(string path, Input input, Output output)
    {
        /*
        > range 2 | transform x {return ($x * 10)} | foreach x {print $x}
        0
        10
        20
        */
        auto varName = input.pop!string();
        auto body = input.pop!SubProgram();
        auto targets = input.popAll();
        if (targets.length == 0)
        {
            auto msg = "no target to transform";
            throw new SyntaxErrorException(
                input.escopo,
                msg
            );
        }

        auto iterator = new Transformer(
            targets, varName, body, input.escopo
        );
        output.push(iterator);
        return ExitCode.Success;
    };
    builtinCommands["transform.inline"] = function(string path, Input input, Output output)
    {
        /*
        > range 65 67 | transform.inline {to.char} | foreach x {print $x}
        A
        B
        C
        > range 65 67 | {to.char} | foreach x {print $x}
        A
        B
        C
        */
        auto body = input.pop!SubProgram();
        auto targets = input.popAll();
        if (targets.length == 0)
        {
            auto msg = "no target to transform.inline";
            throw new SyntaxErrorException(
                input.escopo,
                msg
            );
        }

        auto iterator = new Transformer(
            targets, null, body, input.escopo
        );
        output.push(iterator);
        return ExitCode.Success;
    };

    builtinCommands["range"] = function (string path, Input input, Output output)
    {
        /*
        > range 10       # [zero, 10]
        > range 10 20    # [10, 20]
        > range 10 14 2  # 10 12 14
        */
        auto start = input.pop!long();
        auto limit = input.pop!long(cast(long)null);
        if (limit is cast(long)null)
        {
            // zero to...
            limit = start;
            start = 0;
        }
        if (start > limit)
        {
            throw new InvalidArgumentsException(input.escopo, "Invalid range");
        }

        auto step = input.pop!long(1);
        auto range = new IntegerRange(start, limit, step);

        output.push(range);
        return ExitCode.Success;
    };

    builtinCommands["foreach"] = function(string path, Input input, Output output)
    {
        /*
        > range 2 | foreach x { print $x }
        0
        1
        2
        */
        auto argName = input.pop!string();
        auto argBody = input.pop!SubProgram();

        foreach (target; input.popAll)
        {
            Item range = target.range();

            forLoop:
            while (true)
            {
                auto nextOutput = new Output;
                auto exitCode = range.next(input.escopo, nextOutput);
                final switch (exitCode)
                {
                    case ExitCode.Break:
                        break forLoop;
                    case ExitCode.Skip:
                        continue;
                    case ExitCode.Continue:
                        break;  // <-- break the switch, not the while.
                    case ExitCode.Return:
                    case ExitCode.Success:
                        return exitCode;
                }

                input.escopo[argName] = nextOutput.items;
                exitCode = argBody.run(input.escopo, output);

                if (exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (exitCode == ExitCode.Return)
                {
                    /*
                    Return propagates up into the
                    processes stack and we
                    don't want that.
                    */
                    return ExitCode.Success;
                }
            }
        }

        return ExitCode.Success;
    };
    builtinCommands["foreach.inline"] = function(string path, Input input, Output output)
    {
        /*
        > range 2 | foreach.inline { print }
        0
        1
        2
        > range 2 | { print }
        0
        1
        2
        */
        auto argBody = input.pop!SubProgram();

        uint index = 0;
        foreach (target; input.popAll)
        {
            Item range = target.range();

            forLoop:
            while (true)
            {
                auto nextOutput = new Output;
                auto exitCode = range.next(input.escopo, nextOutput);
                final switch (exitCode)
                {
                    case ExitCode.Break:
                        break forLoop;
                    case ExitCode.Skip:
                        continue;
                    case ExitCode.Continue:
                        break;  // <-- break the switch, not the while.
                    case ExitCode.Return:
                    case ExitCode.Success:
                        return exitCode;
                }

                // use nextOutput as inputs for argBody:
                log("-- foreach.inline argBody inputs: ", nextOutput.items);
                exitCode = argBody.run(input.escopo, nextOutput.items, output);

                if (exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (exitCode == ExitCode.Return)
                {
                    /*
                    Return propagates up into the
                    processes stack:
                    */
                    return ExitCode.Success;
                }
            }
        }

        return ExitCode.Success;
    };
    builtinCommands["loop"] = function(string path, Input input, Output output)
    {
        output.push(new Loop());
        return ExitCode.Success;
    };
    builtinCommands["filter"] = function(string path, Input input, Output output)
    {
        /*
        > range 10 | filter { o : mod 2 : eq 0 }
        2
        4
        6
        8
        10
        */
        auto body = input.pop!SubProgram();
        auto targets = input.popAll();
        if (targets.length == 0)
        {
            auto msg = "no target to filter";
            throw new SyntaxErrorException(
                input.escopo,
                msg
            );
        }

        auto iterator = new Filter(
            targets, body, input.escopo
        );
        output.push(iterator);
        return ExitCode.Success;
    };

    builtinCommands["try"] = function(string path, Input input, Output output)
    {
        /*
        try { subcommand } { return default_value }
        */
        auto body = input.pop!SubProgram;
        auto default_body = input.pop!SubProgram(null);

        ExitCode exitCode;
        try
        {
            exitCode = body.run(input.escopo, output);
        }
        catch (NowException ex)
        {
            auto error = ex.toError;
            if (default_body !is null)
            {
                auto newScope = input.escopo.addPathEntry("catch");

                newScope["error"] = error;
                return default_body.run(newScope, output);
            }
            else
            {
                stderr.writeln("e> ", error);
            }
        }

        return ExitCode.Success;
    };
    builtinCommands["call"] = function(string path, Input input, Output output)
    {
        /*
        > call print "something"
        something
        */
        auto name = input.pop!string();

        auto newInput = Input(
            input.escopo,
            input.inputs,
            input.args[1..$],
            input.kwargs
        );
        return input.escopo.document.runProcedure(name, newInput, output);
    };

    // Hashes
    builtinCommands["md5"] = function(string path, Input input, Output output)
    {
        string target = input.pop!string();
        output.push(target.hexDigest!MD5.to!string);
        return ExitCode.Success;
    };
    builtinCommands["uuid.sha1"] = function(string path, Input input, Output output)
    {
        string source = input.pop!string();
        string result;
        /*
        // TODO: use kwargs!
        {
            input = ?
            auto namespace = sha1UUID(input.pop!string());
            result = sha1UUID(source, namespace).to!string;
        }
        */
        result = sha1UUID(source).to!string;
        output.push(result);
        return ExitCode.Success;
    };
    builtinCommands["uuid.random"] = function(string path, Input input, Output output)
    {
        output.push(randomUUID().to!string);
        return ExitCode.Success;
    };

    // Random
    builtinCommands["random"] = function(string path, Input input, Output output)
    {
        auto a = input.pop!Item();
        auto b = input.pop!Item();

        if (a.type == ObjectType.Float || b.type == ObjectType.Float)
        {
            /*
            > random 0.1 0.5
            # A random number greater or equal to 0.1
            # and lower than 0.5.
            */
            auto af = cast(Float)a;
            auto bf = cast(Float)b;
            output.push(uniform(af.toFloat(), bf.toFloat()));
            return ExitCode.Success;
        }
        else
        {
            /*
            > random 1 3
            # A random number between 1 and 3.
            */
            auto ai = cast(Integer)a;
            auto bi = cast(Integer)b;
            output.push(uniform(ai.toLong(), bi.toLong() + 1));
            return ExitCode.Success;
        }
    };
    builtinCommands["prop"] = function(string path, Input input, Output output)
    {
        string key = input.pop!string;
        auto target = input.pop!Item;

        Item* p = (key in target.properties);
        if (p is null)
        {
            throw new NotFoundException(
                input.escopo,
                "property not found: " ~ key,
                target,
                -1
            );
        }
        output.push(*p);
        return ExitCode.Success;
    };

    // OPERATORS
    /*
    Since we changed the syntax for calling *methods*, now we must
    have these operators as builtinCommands so they will identify
    the target and call its correspondent method...
    */
    builtinCommands["."] = function(string path, Input input, Output output)
    {
        auto target = input.pop!Item;
        log("- builtinCommands[.]: calling `", path, "` on ", target, ":", target.type);
        return target.runMethod(path, input, output);
    };
    builtinCommands[":"] = function(string path, Input input, Output output)
    {
        /*
        > path /boot/grub | as p
        > print ($p : basename)
        --> : $p basename

        (Doesn't work as a commandCall, though.)
        */
        auto target = input.pop!Item;
        auto methodName = input.pop!string;
        return target.runMethod(methodName, input, output);
    };
    builtinCommands["+"] = builtinCommands["."];
    builtinCommands["-"] = builtinCommands["."];
    builtinCommands["*"] = builtinCommands["."];
    builtinCommands["/"] = builtinCommands["."];
    builtinCommands["%"] = builtinCommands["."];
    builtinCommands["=="] = builtinCommands["."];
    builtinCommands["!="] = builtinCommands["."];
    builtinCommands[">"] = builtinCommands["."];
    builtinCommands["<"] = builtinCommands["."];
    builtinCommands[">="] = builtinCommands["."];
    builtinCommands["<="] = builtinCommands["."];
    builtinCommands["&&"] = builtinCommands["."];
    builtinCommands["||"] = builtinCommands["."];


    // SubProgram related:
    builtinCommands["run"] = function (string path, Input input, Output output)
    {
        /*
        > run { print 123 }
        123

        > o 1 | run {as x ; o 1 : add $x} : eq 2 : assert

        Specially useful in conjunction with `when`:
        > set x 1
        > run {
              when ($x == 0) {zero}
              when ($x == 1) {one}
              default {other}
          } | print
        one
        */
        auto body = input.pop!SubProgram;
        auto escopo = input.escopo.addPathEntry("run");
        auto exitCode = body.run(escopo, input.popAll, output);
        if (exitCode == ExitCode.Return)
        {
            exitCode = ExitCode.Success;
        }
        return exitCode;
    };

    // Others
    loadBase64Commands(builtinCommands);
    loadCsvCommands(builtinCommands);
    loadIniCommands(builtinCommands);
    loadJsonCommands(builtinCommands);
    loadHttpCommands(builtinCommands);
    loadMarkdownCommands(builtinCommands);
    loadTemplateCommands(builtinCommands);
    loadTerminalCommands(builtinCommands);
    loadTCPCommands(builtinCommands);
    loadUrlCommands(builtinCommands);
}
