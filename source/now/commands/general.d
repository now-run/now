module now.commands.general;

import core.thread : Thread;
import std.algorithm : canFind;
import std.array;
import std.datetime;
import std.digest.md;
import std.file : chdir, getcwd, read;
import std.random : uniform;
import std.stdio;
import std.string : strip, toLower;
import std.uuid : sha1UUID, randomUUID;

import now.nodes;

import now.commands;
import now.grammar;

import now.commands.base64;
import now.commands.csv;
import now.commands.dotenv;
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
        foreach (item; input.popAll)
        {
            output.push(item.toString());
        }
        return ExitCode.Success;
    };
    builtinCommands["to.bool"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            output.push(item.toBool());
        }
        return ExitCode.Success;
    };
    builtinCommands["to.integer"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            output.push(item.toLong());
        }
        return ExitCode.Success;
    };
    builtinCommands["to.float"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
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
    builtinCommands["inject"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            output.push(item);
        }
        return ExitCode.Inject;
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
    builtinCommands["print"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            stdout.write(item);
        }
        stdout.writeln();
        return ExitCode.Success;
    };
    builtinCommands["print.sameline"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            stdout.write(item);
        }
        stdout.flush;
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

        bool newline = true;
        if (auto newlineRef = ("newline" in input.kwargs))
        {
            newline = (*newlineRef).toBool;
        }

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
            switch (level)
            {
                case LogLevel.Warning:
                    printColor(200, 150, 0, input.popAll, stderr);
                    break;
                case LogLevel.Error:
                    printColor(255, 0, 0, input.popAll, stderr);
                    break;
                case LogLevel.Debug:
                    printColor(200, 200, 200, input.popAll, stderr);
                    break;
                default:
                    foreach (item; input.popAll)
                    {
                        stderr.write(item.toString);
                    }
                    if (newline)
                    {
                        stderr.writeln;
                    }
            }
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

                switch (level)
                {
                    case LogLevel.Warning:
                        printColor(200, 150, 0, logOutput.items, stderr);
                        break;
                    case LogLevel.Error:
                        printColor(255, 0, 0, logOutput.items, stderr);
                        break;
                    case LogLevel.Debug:
                        printColor(200, 200, 200, logOutput.items, stderr);
                        break;
                    default:
                        foreach (x; logOutput.items)
                        {
                            stderr.write(x);
                        }
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
    builtinCommands["prompt"] = function(string path, Input input, Output output)
    {
        /*
        > o "this!" | prompt "select a letter: "
            . (a = {print})
        select a letter: a
        this!
        */

        auto message = input.pop!string;
        auto defaultKeyRef = ("default" in input.kwargs);
        string defaultKey;

        if (stdin.eof)
        {
            return ExitCode.Break;
        }

        if (defaultKeyRef is null)
        {
            stderr.write(message);
        }
        else
        {
            defaultKey = (*defaultKeyRef).toString;
            stderr.write(message ~ "[" ~ defaultKey ~ "] ");
        }
        stderr.flush();

        Item[string] options;

        foreach (item; input.args[1..$])
        {
            auto pair = cast(Pair)item;
            auto key = pair.items[0].toString;
            auto value = pair.items[1];
            options[key] = value;
        }

        if (options.length == 0)
        {
            if (stdin.eof)
            {
                stderr.writeln("EOF");
                stderr.flush();
                return ExitCode.Break;
            }
            string content = stdin.readln.to!string.strip();

            if (content.length == 0)
            {
                if (defaultKey is null)
                {
                    return ExitCode.Skip;
                }
                else
                {
                    output.push(defaultKey);
                    return ExitCode.Success;
                }
            }
            else
            {
                output.push(content);
            }
            return ExitCode.Success;
        }
        else
        {
            auto unknownHandlerRef = ("unknown" in input.kwargs);

            while (true)
            {
                string key;
                if (stdin.eof)
                {
                    stderr.writeln("EOF");
                    stderr.flush();
                    return ExitCode.Break;
                }
                else {
                    key = stdin.readln.to!string.strip;
                }

                if (key.length == 0)
                {
                    if (defaultKey !is null)
                    {
                        key = defaultKey;
                    }
                }

                auto valueRef = (key in options);
                Item value;
                if (valueRef is null)
                {
                    if (unknownHandlerRef is null)
                    {
                        stderr.writeln("Invalid option!");
                        continue;
                    }
                    else
                    {
                        value = *unknownHandlerRef;
                    }
                }
                else
                {
                    value = *valueRef;
                }

                if (value.type != ObjectType.SubProgram)
                {
                    throw new InvalidArgumentsException(
                        input.escopo,
                        path
                        ~ " expects a SubProgram as value for "
                        ~ key
                    );
                }
                auto subprogram = cast(SubProgram)value;
                auto exitCode = subprogram.run(
                    input.escopo, input.inputs, output
                );
                if (exitCode == ExitCode.Success)
                {
                    // SubProgram didn't return, so
                    // we'll pass forward the key:
                    output.push(key);
                }
                else if (exitCode == ExitCode.Return)
                {
                    exitCode = ExitCode.Success;
                }
                return exitCode;
            }
        }
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
    builtinCommands["isotime.decode"] = function(string path, Input input, Output output)
    {
        /*
        o "2027-12-25 12:34:56.300" | isotime.decode
        9999999999  # unixtime
        */
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
        auto message = input.pop!string("");

        throw new UserException(
            input.escopo,
            message,
            code,
            null
        );
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
    builtinCommands["unset"] = function(string path, Input input, Output output)
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

        foreach (argument; input.popAll)
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

    builtinCommands["pair"] = function(string path, Input input, Output output)
    {
        /*
        > pair 1 2
        > o (key = value)
        > set interval (0 to 50)
        > set coordinates [pair 29.0 -70.0]
        */
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
    builtinCommands["="] = builtinCommands["pair"];
    builtinCommands["to"] = builtinCommands["pair"];

    builtinCommands["path"] = function(string name, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            string path = item.toString;
            output.push(new Path(path));
        }
        return ExitCode.Success;
    };
    builtinCommands["http"] = function(string name, Input input, Output output)
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

        Anything from 3rd position on (that is, input.inputs)
        is passed as inputs (as if coming from a pipe) for the body:
        > if true {print "what> "} "WHAT?"
        what> WHAT?

        So this construct can work:

        > list 1 2 3
            | if $debug {o | as lista ; log $lista ; inject $lista}
            | return

        If the body doesn't Inject, then the same input will
        be used as output:

        list 1 2 3
            | if $debug {o | as lista ; log $lista}
            | return
        */
        bool condition;
        auto conditionBody = input.pop!Item;
        auto thenBody = input.pop!SubProgram;
        auto inputs = input.popAll;

        if (conditionBody.type == ObjectType.SubProgram)
        {
            auto subprogram = cast(SubProgram)conditionBody;

            auto conditionOutput = new Output();
            auto exitCode = subprogram.run(input.escopo, inputs, conditionOutput);
            if (conditionOutput.items.length == 0)
            {
                condition = false;
            }
            else
            {
                condition = true;
                foreach (item; conditionOutput.items)
                {
                    if (!item.toBool)
                    {
                        condition = false;
                        break;
                    }
                }
            }
        }
        else
        {
            condition = conditionBody.toBool;
        }

        if (condition)
        {
            auto exitCode = thenBody.run(input.escopo, inputs, output);
            if (exitCode == ExitCode.Inject)
            {
                log("if -> Inject -> Success");
                log(output);
                return ExitCode.Success;
            }
            else if (exitCode == ExitCode.Return)
            {
                log("if -> Return");
                log(output);
                return exitCode;
            }
            else
            {
                log("if -> ", exitCode);
                output.items = inputs;
                return exitCode;
            }
        }
        else
        {
            output.push(inputs);
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

    builtinCommands["range"] = function(string path, Input input, Output output)
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
    builtinCommands["take"] = function(string path, Input input, Output output)
    {
        /*
        > range 100000 | take 3 | {print}
        0
        1
        2
        */
        auto n = input.pop!long();
        output.push(new TakeRange(n, input.popAll));
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
                    // TODO: check if this makes any sense:
                    case ExitCode.Inject:
                        return ExitCode.Success;
                }

                input.escopo[argName] = nextOutput.items;
                exitCode = argBody.run(input.escopo, output);

                if (exitCode == ExitCode.Break)
                {
                    break;
                }
                switch (exitCode)
                {
                    case ExitCode.Return:
                        return exitCode;
                    case ExitCode.Inject:
                        return ExitCode.Return;
                    default:
                        continue;
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
                    // TODO: check if this makes any sense:
                    case ExitCode.Inject:
                        return ExitCode.Success;
                }

                // use nextOutput as inputs for argBody:
                log("-- foreach.inline argBody inputs: ", nextOutput.items);
                exitCode = argBody.run(input.escopo, nextOutput.items, output);

                if (exitCode == ExitCode.Break)
                {
                    break;
                }
                switch (exitCode)
                {
                    case ExitCode.Return:
                        return exitCode;
                    case ExitCode.Inject:
                        return ExitCode.Success;
                    default:
                        continue;
                }
            }
        }

        return ExitCode.Success;
    };

    builtinCommands["loop"] = function(string path, Input input, Output output)
    {
        long wait = 0;
        auto waitRef = ("wait" in input.kwargs);
        if (waitRef is null)
        {
            output.push(new Loop());
        }
        else
        {
            auto item = *waitRef;
            wait = item.toLong;
            output.push(new WaitLoop(wait));
        }
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

        // XXX: We're going to popAll, so
        // we will fix the weird behavior
        // of .inputs being kept...
        input.inputs = [];

        auto newInput = Input(
            input.escopo,
            input.inputs,
            input.popAll,
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

        auto defaultItemRef = ("default" in input.kwargs);

        foreach (target; input.popAll)
        {
            Item* p = (key in target.properties);
            if (p is null)
            {
                if (defaultItemRef !is null) {
                    p = defaultItemRef;
                }
                else {
                    throw new NotFoundException(
                        input.escopo,
                        "property not found: " ~ key,
                        target,
                        -1
                    );
                }
            }
            output.push(*p);
        }
        return ExitCode.Success;
    };
    builtinCommands["setprop"] = function(string path, Input input, Output output)
    {
        /*
        return [o false | setprop (reason = "invalid token") (status = $status)]
        */
        string key = input.pop!string;
        Item item = input.inputs.front;

        foreach (pairItem; input.args)
        {
            if (pairItem.type != ObjectType.Pair)
            {
                throw new InvalidArgumentsException(
                    input.escopo,
                    path
                    ~ " expects only Pairs as arguments."
                );
            }
            auto pair = cast(Pair)pairItem;
            item.properties[pair.key.toString] = pair.value;
        }

        output.push(item);

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
    builtinCommands[":"] = builtinCommands["on"];
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
    builtinCommands["incr"] = function(string path, Input input, Output output)
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
    builtinCommands["decr"] = function(string path, Input input, Output output)
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
    builtinCommands["run"] = function(string path, Input input, Output output)
    {
        /*
        > o 123 | run {o 456} | print
        123

        > o 123 | run {return 456} | print
        456
        */
        auto body = input.pop!SubProgram;
        auto items = input.popAll;

        auto escopo = input.escopo.addPathEntry("run");
        foreach (key, value; input.kwargs)
        {
            escopo[key] = value;
        }

        auto bodyOutput = new Output;
        auto exitCode = body.run(escopo, items, bodyOutput);
        log("run body exitCode is: ", exitCode);
        if (exitCode == ExitCode.Inject)
        {
            output.items = bodyOutput.items;
            exitCode = ExitCode.Success;
        }
        else if (exitCode == ExitCode.Return)
        {
            output.items = bodyOutput.items;
        }
        else
        {
            output.items = items;
        }
        return exitCode;
    };
    builtinCommands[">>"] = builtinCommands["run"];

    builtinCommands["aside"] = function(string path, Input input, Output output)
    {
        /*
        > o 123 | aside {print "inner: "} | print "outer: "
        inner:
        outer: 123

        The aside won't receive any inputs.
        */
        auto body = input.pop!SubProgram;
        auto items = input.popAll;

        auto escopo = input.escopo.addPathEntry("aside");
        foreach (key, value; input.kwargs)
        {
            escopo[key] = value;
        }

        auto aOutput = new Output;
        auto exitCode = body.run(escopo, aOutput);
        if (exitCode == ExitCode.Inject)
        {
            output.items = aOutput.items;
            exitCode = ExitCode.Success;
        }
        else if (exitCode == ExitCode.Return)
        {
            output.items = aOutput.items;
        }
        else
        {
            output.items = items;
        }
        return exitCode;
    };
    builtinCommands["__"] = builtinCommands["aside"];

    builtinCommands["once"] = function(string path, Input input, Output output)
    {
        /*
        > once { count_and_print } key
        1
        > once { count_and_print } key
        1

        count_and_print will be called only once!
        */
        auto body = input.pop!SubProgram;

        string key = "__once:" ~ makeKeyFromInputs(input);
        log("once key is: ", key);

        auto escopo = input.escopo.addPathEntry("once");
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

    builtinCommands["cache"] = function(string path, Input input, Output output)
    {
        /*
        > cache { count_and_print } key -- (ttl = 600)
        1
        > cache { count_and_print } key -- (ttl = 600)
        1

        count_and_print will be called only once!
        */
        auto body = input.pop!SubProgram;

        string key = "__cache:" ~ makeKeyFromInputs(input);
        log("cache key is: ", key);

        auto escopo = input.escopo.addPathEntry("cache");
        auto value = escopo.get(key, null);

        ExitCode exitCode;

        // TODO: evaluate ttl!

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
    builtinCommands["syscmd"] = function(string path, Input input, Output output)
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

        foreach (key, value; input.kwargs)
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
    builtinCommands["cwd"] = function(string path, Input input, Output output)
    {
        auto cwd = getcwd();
        output.push(cwd);
        return ExitCode.Success;
    };

    builtinCommands["chdir"] = function(string path, Input input, Output output)
    {
        /*
        > cwd | print
        a/b
        > o "c" | chdir {
            > cwd | print
            a/b/c
        }
        > cwd | print
        a/b
        */
        auto previous = getcwd();
        auto subprogram = input.pop!SubProgram;
        auto dir = input.pop!string;

        // Change to new directory:
        dir.chdir;
        scope(exit) previous.chdir;

        auto exitCode = subprogram.run(input.escopo, output);

        return exitCode;
    };

    // Others
    loadBase64Commands(builtinCommands);
    loadCsvCommands(builtinCommands);
    loadDotEnvCommands(builtinCommands);
    loadIniCommands(builtinCommands);
    loadJsonCommands(builtinCommands);
    loadHttpCommands(builtinCommands);
    loadMarkdownCommands(builtinCommands);
    loadTemplateCommands(builtinCommands);
    loadTerminalCommands(builtinCommands);
    loadTCPCommands(builtinCommands);
    loadUrlCommands(builtinCommands);
}
