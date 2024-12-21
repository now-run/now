module now.commands.general;

import core.thread : Thread;
import std.algorithm : canFind;
import std.algorithm.mutation : stripRight;
import std.array;
import std.datetime;
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

import now.commands.utils;


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
    builtinCommands["o"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            output.push(item);
        }
        return ExitCode.Success;
    };

    builtinCommands["collect"] = function(string path, Input input, Output output)
    {
        Items items;

        iterateOverGenerators(
            input.escopo,
            input.popAll,
            (Items generatedItems) {
                items ~= generatedItems;
            }
        );

        output.push(new List(items));
        return ExitCode.Success;
    };
    builtinCommands["sequence"] = function(string path, Input input, Output output)
    {
        iterateOverGenerators(
            input.escopo,
            input.popAll,
            (Items generatedItems) {
                output.push(generatedItems);
            }
        );
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
    builtinCommands["success"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            output.push(item);
        }
        return ExitCode.Success;
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
                        erro.classe,
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
        auto exitCode = body.run(newScope, input.popAll, output);
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
        stdout.writeln();
        return ExitCode.Success;
    };
    builtinCommands["print.sameline"] = function (string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            stdout.write(item);
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
        auto exitCode = ExitCode.Success;
        LogLevel level = LogLevel.Info;

        if (path.canFind('.'))
        {
            auto parts = path.split(".");
            auto levelStr = parts[1];
            switch (levelStr)
            {
                case "debug":
                    level = LogLevel.Debug;
                    break;
                case "info":
                    level = LogLevel.Info;
                    break;
                case "warning":
                    level = LogLevel.Warning;
                    break;
                case "error":
                    level = LogLevel.Error;
                    break;
                default:
                    throw new InvalidException(
                        input.escopo,
                        "Unkown log level: " ~ levelStr
                    );
            }
        }

        if (level < input.escopo.document.logLevel)
        {
            return ExitCode.Success;
        }

        string formatName = "default";
        if (auto fmtPtr = ("format" in input.kwargs))
        {
            formatName = (*fmtPtr).toString;
        }

        auto escopo = input.escopo;
        auto document = escopo.document;

        auto format = document.logFormats.get(formatName, null);

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
            auto logOutput = new Output();
            foreach (index, item; input.popAll)
            {
                auto newScope = input.escopo.addPathEntry(
                    "log/" ~ formatName ~ "/" ~ index.to!string
                );
                newScope["message"] = item;

                exitCode = format.run(newScope, logOutput);
                if (exitCode == ExitCode.Return)
                {
                    exitCode = ExitCode.Success;
                }
                // TODO: handle the exit code!

                bool hasOutput = false;
                foreach (x; logOutput.items)
                {
                    stderr.write(x);
                    hasOutput = true;
                }
                if (hasOutput)
                {
                    stderr.writeln();
                }
                logOutput.items.length = 0;
            }
        }

        stderr.flush();

        return exitCode;
    };
    builtinCommands["log.debug"] = builtinCommands["log"];
    builtinCommands["log.info"] = builtinCommands["log"];
    builtinCommands["log.warning"] = builtinCommands["log"];
    builtinCommands["log.error"] = builtinCommands["log"];

    /**
    Read the entire stdin.
    */
    builtinCommands["read"] = function(string path, Input input, Output output)
    {
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
        Thread.sleep(ms.msecs);
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
        > timer | as t
        > list 1 2 3 4 5 | {:: * 10} | collect | log "collected="
        > o $t : nsecs | print "nsecs: "
        50000
        */
        string description;
        if (input.items.length > 0)
        {
            description = input.pop!string;
        }
        output.push(new Timer(description));

        return ExitCode.Success;
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
    > error classe code class
    > error "Not Found" 404 http
    > error "segmentation fault" 11 os
    ---
    */
    builtinCommands["error"] = function(string path, Input input, Output output)
    {
        string classe = input.pop!string("An error ocurred");
        int code = cast(int)(input.pop!long(-1));

        throw new UserException(
            input.escopo,
            classe,
            code
        );
    };
    builtinCommands["switch"] = function(string path, Input input, Output output)
    {
        /*
        o 123
            | type
            | switch
            ! integer {print "is an integer"}
            ! * {print "not an integer"}
        */
        auto item = input.pop!Item;
        throw new Event(input.escopo, item.toString);
    };

    builtinCommands["exit"] = function(string path, Input input, Output output)
    {
        // TODO: make it actually work and exit from anywhere.
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
        // > list 1 2 3 | as lista | :: length | print
        output.push(values);
        return ExitCode.Success;
    };
    builtinCommands["as"] = builtinCommands["set"];
    builtinCommands["quickset"] = function(string path, Input input, Output output)
    {
        auto key = input.pop!string;
        auto value = input.pop!Item;
        input.escopo[key] = value;
        return ExitCode.Success;
    };
    builtinCommands["unset"] = function (string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            input.escopo.remove(item.toString);
        }
        return ExitCode.Success;
    };

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
        // XXX: why "evaluate"?
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
        /*
        > if true {print "TRUE!"}
        TRUE!
        */
        auto condition = input.pop!bool;
        auto thenBody = input.pop!SubProgram;
        auto inputs = input.popAll;

        if (condition)
        {
            return thenBody.run(input.escopo, inputs, output);
        }

        return ExitCode.Success;
    };
    builtinCommands["run.if"] = function(string path, Input input, Output output)
    {
        /*
        > run.if true {print "TRUE!"}
        TRUE!


        Anything from 3rd position on is passed
        as inputs for the body:
        > if true {print "what> "} "WHAT?"
        what> WHAT?

        So this construct can work:

        list 1 2 3
            | run.if $debug {o | as lista ; log $lista ; return $lista}
            | return

        If the body doesn't Return, then the same input will
        be used as output:

        list 1 2 3
            | run.if $debug {o | as lista ; log $lista}
            | return
        */
        auto condition = input.pop!bool;
        auto thenBody = input.pop!SubProgram;
        auto inputs = input.popAll;

        if (condition)
        {
            auto exitCode = thenBody.run(input.escopo, inputs, output);
            switch (exitCode)
            {
                case ExitCode.Return:
                    return ExitCode.Success;

                default:
                    output.items = inputs;
                    return exitCode;
            }
        }

        return ExitCode.Success;
    };

    builtinCommands["any"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            if (item.toBool == true)
            {
                output.push(true);
                return ExitCode.Success;
            }
        }
        // else
        output.push(false);
        return ExitCode.Success;
    };
    builtinCommands["all"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            if (item.toBool == false)
            {
                output.push(false);
                return ExitCode.Success;
            }
        }
        // else
        output.push(true);
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
    builtinCommands["run.foreach"] = function(string path, Input input, Output output)
    {
        /*
        > range 2 | run.foreach { print "+ " } | print
        + 0
        + 1
        + 2
        Range
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
    builtinCommands["count"] = function(string path, Input input, Output output)
    {
        foreach (target; input.popAll)
        {
            auto range = target.range();

            long count = 0;
countLoop:
            while (true)
            {
                auto nextOutput = new Output;
                auto exitCode = range.next(input.escopo, nextOutput);
                switch (exitCode)
                {
                    case ExitCode.Return:
                    case ExitCode.Break:
                        break countLoop;
                    case ExitCode.Skip:
                        continue countLoop;

                    default:
                        count++;
                }
            }
            output.push(count);
        }
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
    builtinCommands["on"] = function(string path, Input input, Output output)
    {
        /*
        > list a b c | as lista
        > on $lista get 2 | print
        c

        > o 2 | on $lista get | print
        c
        */
        auto target = input.pop!Item;
        auto methodName = input.pop!string;
        return target.runMethod(methodName, input, output);
    };
    builtinCommands["method"] = function(string path, Input input, Output output)
    {
        /*
        > list a b c | method push d | print
        (a , b , c , d)

        > o 1 2 3 | method + 10 | print
Currently: 11
Expected: 11 12 13  ???
But what if only one of them returns Skip or Break???

        */
        auto methodName = input.args[0].toString;
        auto target = input.inputs[0];
        input.items = input.args[1..$];
        log("method input.kwargs: ", input.kwargs);
        return target.runMethod(methodName, input, output);
    };
    builtinCommands["::"] = builtinCommands["method"];

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

    // Other useful stuff
    builtinCommands["incr"] = function (string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            string name = item.toString();
            auto obj = input.escopo[name];
            switch (obj.type)
            {
                case ObjectType.Integer:
                    auto i = cast(Integer)obj;
                    auto x = new Integer(i.value + 1);
                    input.escopo[name] = x;
                    output.push(x);
                    break;
                case ObjectType.Float:
                    auto f = cast(Float)obj;
                    auto x = new Float(f.value + 1);
                    input.escopo[name] = x;
                    output.push(x);
                    break;
                default:
                    throw new InvalidArgumentsException(
                        input.escopo,
                        "Value of " ~ name ~ " is a " ~ obj.type.to!string
                        ~ " and cannot be incremented."
                    );
            }
        }
        return ExitCode.Success;
    };
    builtinCommands["decr"] = function (string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            string name = item.toString();
            auto obj = input.escopo[name];
            switch (obj.type)
            {
                case ObjectType.Integer:
                    auto i = cast(Integer)obj;
                    auto x = new Integer(i.value - 1);
                    input.escopo[name] = x;
                    output.push(x);
                    break;
                case ObjectType.Float:
                    auto f = cast(Float)obj;
                    auto x = new Float(f.value - 1);
                    input.escopo[name] = x;
                    output.push(x);
                    break;
                default:
                    throw new InvalidArgumentsException(
                        input.escopo,
                        "Value of " ~ name ~ " is a " ~ obj.type.to!string
                        ~ " and cannot be incremented."
                    );
            }
        }
        return ExitCode.Success;
    };

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
        auto items = input.popAll;

        auto escopo = input.escopo.addPathEntry("run");
        auto exitCode = body.run(escopo, items, output);
        if (exitCode == ExitCode.Return)
        {
            exitCode = ExitCode.Success;
        }
        return exitCode;
    };
    builtinCommands["aposto"] = function (string path, Input input, Output output)
    {
        /*
        > o 123 | aside {o 456} | print
        123

        > o 123 | aside {return 456} | print
        456
        */
        auto body = input.pop!SubProgram;
        auto items = input.popAll;

        auto escopo = input.escopo.addPathEntry("aposto");
        auto bpOutput = new Output;
        auto exitCode = body.run(escopo, items, bpOutput);
        if (exitCode == ExitCode.Return)
        {
            output.items = bpOutput.items;
            exitCode = ExitCode.Success;
        }
        else
        {
            output.items = items;
        }
        return exitCode;
    };
    builtinCommands[">>"] = builtinCommands["aposto"];

    builtinCommands["aside"] = function (string path, Input input, Output output)
    {
        /*
        > o 123 | aposto {print "inner: "} | print "outer: "
        inner:
        outer: 123

        The aposto won't receive any inputs.
        */
        auto body = input.pop!SubProgram;
        auto items = input.popAll;

        auto escopo = input.escopo.addPathEntry("aside");
        auto aOutput = new Output;
        auto exitCode = body.run(escopo, aOutput);
        if (exitCode == ExitCode.Return)
        {
            output.items = aOutput.items;
            exitCode = ExitCode.Success;
        }
        else
        {
            output.items = items;
        }
        return exitCode;
    };
    builtinCommands["__"] = builtinCommands["aside"];

    builtinCommands["once"] = function (string path, Input input, Output output)
    {
        /*
        > once { count_and_print }
        1
        > once { count_and_print }
        1

        count_and_print will be called only once!
        */
        string givenKey = input.pop!string;
        string key = "__once:" ~ givenKey;
        auto body = input.pop!SubProgram;

        auto escopo = input.escopo.addPathEntry("run");
        auto value = escopo.get(key, null);

        ExitCode exitCode;

        if (value !is null)
        {
            output.push(value.evaluate(escopo));
        }
        else
        {
            auto items = input.popAll;
            auto bodyScope = new Output();
            exitCode = body.run(escopo, items, bodyScope);
            if (exitCode == ExitCode.Return)
            {
                exitCode = ExitCode.Success;
            }
            auto returnedValues = bodyScope.items;
            escopo[key] = returnedValues;
            foreach (item; returnedValues)
            {
                output.push(item);
            }
        }
        return exitCode;
    };

    // System commands
    builtinCommands["syscmd"] = function (string path, Input input, Output output)
    {
        import now.system_command : SystemProcess;
        /*
        > syscmd ls / | {print "ls> "}
        ls> bin
        ls> etc
        ls> opt
        ...
        */

        Item inputStream;
        string[string] env;

        string[] cmdline = input.args.map!(x => x.toString).array;

        // Inputs:
        if (input.inputs.length == 1)
        {
            inputStream = input.inputs.front.range;
        }
        else if (input.inputs.length > 1)
        {
            throw new InvalidInputException(
                input.escopo,
                path ~ ": cannot handle multiple inputs",
            );
        }

        foreach(key, value; input.kwargs)
        {
            env[key] = value.toString;
        }

        output.push(new SystemProcess(
            cmdline,
            inputStream,
            env,
            null,  // workdir (string)
            false  // takeover (bool)
        ));
        return ExitCode.Success;
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
