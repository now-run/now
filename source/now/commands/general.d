module now.commands.general;


import std.array;
import std.datetime;
import std.digest.md;
import std.file : read;
import std.stdio;
import std.string : toLower;
import std.algorithm.mutation : stripRight;

import now.nodes;
import now.commands;
import now.commands.http;
import now.commands.json;
import now.commands.iterators;
import now.commands.timer;
import now.grammar;


static this()
{
    // ---------------------------------------------
    // Stack
    commands["stack.push"] = function (string path, Context context)
    {
        /*
        > stack.push 1 2 3 | print
        123
        */
        // Do nothing, the value is already on stack.
        return context;
    };

    commands["stack.pop"] = function (string path, Context context)
    {
        /*
        > stack.push 1 2 3
        > stack.pop | print
        1
        > stack.pop | print
        2
        */
        if (context.process.stack.stackPointer == 0)
        {
            auto msg = "Stack is empty";
            return context.error(msg, ErrorCode.SemanticError, "");
        }

        long quantity = 1;
        if (context.size) {
            quantity = context.pop!long();
        }
        context.size += quantity;
        return context;
    };

    commands["stack"] = function (string path, Context context)
    {
        /*
        > stack.push 1 2 3
        > stack | print
        123
        */
        context.size = cast(int)context.process.stack.stackPointer;
        return context;
    };

    // ---------------------------------------------
    // Native types, nodes and conversion
    commands["typeof"] = function (string path, Context context)
    {
        /*
        > typeof 1.2 | print
        float
        */
        Item target = context.pop();
        context.push(new NameAtom(to!string(target.type).toLower()));

        return context;
    };
    commands["type.name"] = function (string path, Context context)
    {
        /*
        We can have types that behave like strings, for example, but
        are actually distinct from native strings, so it may be useful
        to see their actual name.

        > type.name $extraneous_type
        string_on_steroids
        */
        Item target = context.pop();
        context.push(new NameAtom(to!string(target.typeName).toLower()));

        return context;
    };
    commands["to.string"] = function (string path, Context context)
    {
        foreach(item; context.items.retro)
        {
            context.push(item.toString());
        }

        return context;
    };
    commands["to.bool"] = function (string path, Context context)
    {
        auto target = context.pop();
        return context.push(target.toBool());
    };
    commands["to.integer"] = function (string path, Context context)
    {
        auto target = context.pop();
        return context.push(target.toInt());
    };
    commands["to.float"] = function (string path, Context context)
    {
        auto target = context.pop();
        return context.push(target.toFloat());
    };


    // ---------------------------------------------
    // Various ExitCodes:
    commands["break"] = function (string path, Context context)
    {
        context.exitCode = ExitCode.Break;
        return context;
    };
    commands["continue"] = function (string path, Context context)
    {
        context.exitCode = ExitCode.Continue;
        return context;
    };
    commands["skip"] = function (string path, Context context)
    {
        context.exitCode = ExitCode.Skip;
        return context;
    };
    commands["return"] = function (string path, Context context)
    {
        context.exitCode = ExitCode.Return;
        return context;
    };

    // Scope
    commands["scope"] = function (string path, Context context)
    {
        /*
        > scope "send HTTP request" {
            http.get $url | as content
          }

        When dealing with errors, at least we can see better names
        during long procedures. Good for test cases, too.

        It can be used as support for `autoclose`:
        > scope "read a file" {
            file.open $path | autoclose | as f
            file.read $f | as content
          }
        */
        // TODO: set Escopo name
        string name = context.pop!string();
        SubProgram body = context.pop!SubProgram();

        debug {stderr.writeln("= scope ", name, " =");}

        auto escopo = context.escopo;
        auto newScope = new Escopo(escopo, name);
        newScope.variables = escopo.variables;

        auto returnedContext = context.process.run(
            body, context.next(newScope)
        );
        // XXX: do we still have to close cms by hand?
        returnedContext = context.process.closeCMs(returnedContext);

        context.size = returnedContext.size;
        context.exitCode = returnedContext.exitCode;
        return context;
    };
    commands["autoclose"] = function (string path, Context context)
    {
        /*
        > scope "update sqlite" {
            db.connect $connection_string | autoclose | as db
            ...
          }
        */
        auto contextManager = context.peek();
        debug {stderr.writeln("contextManager:", contextManager);}
        auto escopo = context.escopo;

        context = contextManager.runCommand("open", context);
        debug {stderr.writeln(" cmContext:", context);}

        if (context.exitCode == ExitCode.Failure)
        {
            return context;
        }
        escopo.contextManagers ~= contextManager;

        // Make sure the stack is okay:
        debug {stderr.writeln(" cleaning the stack...");}
        context.items();
        debug {stderr.writeln(" pushing ", contextManager);}
        context.push(contextManager);

        context.exitCode = ExitCode.Success;
        return context;
    };
    commands["uplevel"] = function (string path, Context context)
    {
        /*
        uplevel set parent_value x
        [procedures/superset]
        parameters {
            key {
                type string
            }
            value {
                type any
            }

        log "SETTING $key TO $VALUE"
        uplevel set $key $value

        [procedures/other_one]

        superset a 1
        print $a
        # 1
        */
        auto parentScope = context.escopo.parent;
        if (parentScope is null)
        {
            auto msg = "No upper level to access.";
            return context.error(msg, ErrorCode.SemanticError, "");
        }

        /*
        It is very important to do this `pop` **before**
        copying the context.size into
        newContext.size!
        You see,
        uplevel set x 1 2 3  ← this command has 5 arguments
           -    set x 1 2 3  ← and this one has 4
        */
        auto cmdName = context.pop!(string);

        /*
        Also important to remember: `uplevel` is a command itself.
        As such, all its arguments were already evaluated
        when it was called, so we can safely assume
        there's no further  substitutions to be
        made and this is going to apply to
        the command we are calling
        */
        auto cmdArguments = context.items;

        // 1- create a new CommandCall
        auto command = new CommandCall(cmdName, cmdArguments);

        // 2- create a new context, with the parent
        //    scope as the context.escopo
        auto newContext = context.next();
        newContext.escopo = parentScope;
        newContext.size = context.size;

        // 3- run the command
        auto returnedContext = command.run(newContext);

        if (returnedContext.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.Success;
        }
        return context;
    };
    commands["with"] = function (string path, Context context)
    {
        /*
        # No `with`:
        > open $file
        > read $file | as content
        > close $file

        # With `with`:
        > with $file {
            open
            read | as content
            close
          }
        */
        auto target = context.pop();
        auto body = context.pop!SubProgram();

        foreach (pipeline; body.pipelines)
        {
            auto commandCall = pipeline.commandCalls.front;
            commandCall.arguments = [target] ~ commandCall.arguments;
        }

        context = context.process.run(body, context.escopo);

        return context;
    };


    // ---------------------------------------------
    // Text I/O:
    commands["print"] = function (string path, Context context)
    {
        while(context.size) stdout.write(context.pop!string());
        stdout.writeln();
        return context;
    };
    commands["log"] = function (string path, Context context)
    {
        /*
        [logging/formats/default]
        include {
            - timestamp
            - hostname
        }

        get $program directory | as pd
        return '{"timestamp":$timestamp, "hostname":"$hostname", "path":$pd, "message":$message}'
        */
        string formatName;
        if (context.size == 1)
        {
            formatName = "default";
        }
        else if (context.size == 2)
        {
            formatName = context.pop!string();
        }
        else
        {
            return context.error(
                path ~ " must receive 1 or 2 arguments.",
                ErrorCode.InvalidSyntax,
                ""
            );
        }

        auto format = context.program.get!Dict(
            ["logging", "formats", formatName],
            delegate (Dict d) {
                return cast(Dict)null;
            }
        );

        if (format !is null)
        {
            auto body = format["body"];
            auto parser = new Parser(body.toString());
            // TODO: cache it:
            auto subprogram = parser.consumeSubProgram();

            auto newScope = new Escopo(context.escopo);
            newScope["message"] = context.pop!String();
            context = context.process.run(subprogram, context.next(newScope));
            if (context.exitCode != ExitCode.Failure)
            {
                context.exitCode = ExitCode.Success;
            }
        }

        while(context.size) stderr.write(context.pop!string());
        stderr.writeln();
        return context;
    };
    commands["print.sameline"] = commands["print"];

    commands["read"] = function (string path, Context context)
    {
        // read a line from std.stdin
        return context.push(new String(stdin.readln().stripRight('\n')));
    };

    // ---------------------------------------------
    // Time
    integerCommands["sleep"] = function (string path, Context context)
    {
        import std.datetime.stopwatch;

        auto ms = context.pop!long();

        auto sw = StopWatch(AutoStart.yes);
        while(true)
        {
            auto passed = sw.peek.total!"msecs";
            if (passed >= ms)
            {
                break;
            }
        }
        return context;
    };
    commands["unixtime"] = function (string path, Context context)
    {
        SysTime today = Clock.currTime();
        return context.push(today.toUnixTime!long());
    };
    // ---------------------------------------------
    // Errors
    commands["error"] = function (string path, Context context)
    {
        /*
        Signalize that an error occurred.

        > error "something wrong happened"

        It's a kind of equivalent to `return`,
        so no need to "return [error ...]". Just
        calling `error` will exit 
        */
        string classe = "";
        int code = -1;
        string message = "An error ocurred";

        // "Full" call:
        // error message code class
        // error "Not Found" 404 http
        // error "segmentation fault" 11 os
        if (context.size > 0)
        {
            message = context.pop!string();
        }
        if (context.size > 0)
        {
            code = cast(int)context.pop!long();
        }
        if (context.size > 0)
        {
            classe = context.pop!string();
        }

        return context.error(message, code, classe);
    };

    // ---------------------------------------------
    // Debugging
    commands["assert"] = function (string path, Context context)
    {
        /*
        > assert true
        > assert false
        assertion error: false
        */
        foreach (item; context.items)
        {
            if (!item.toBool())
            {
                auto msg = "assertion error: " ~ item.toString();
                return context.error(msg, ErrorCode.AssertionError, "");
            }
        }
        return context;
    };

    commands["exit"] = function (string path, Context context)
    {
        /*
        [procedures/quit]
        parameters {
            code {
                type int
            }
        }

        [commands/run]
        parameters {}

        quit 10
        ---
        $ now ; echo $?
        10
        */
        string classe = "";
        string message = "Process was stopped";

        long code = 0;

        if (context.size)
        {
            code = context.pop!long();
        }

        if (context.size > 0)
        {
            message = context.pop!string();
        }

        if (code == 0)
        {
            context.exitCode = ExitCode.Return;
            return context;
        }
        else
        {
            return context.error(message, cast(int)code, classe);
        }
    };

    // Names:
    commands["set"] = function (string path, Context context)
    {
        /*
        > set a 1
        > print $a
        1
        */
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` must receive at least two arguments.";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto key = context.pop!string();
        context.escopo[key] = context.items;

        return context;
    };
    commands["as"] = commands["set"];

    commands["val"] = function (string path, Context context)
    {
        /*
        > set x 10
        > val x | print
        10
        */
        auto name = context.pop();
        Items value;
        try
        {
            value = context.escopo[name.toString()];
        }
        catch (NotFoundException ex)
        {
            return context.push(ex.to!string);
        }
        return context.push(value);
    };
    commands["value_of"] = function (string path, Context context)
    {
        /*
        > dict (a = 30) | value_of a | print
        30
        # It's simply an inverted `get`.
        > dict (a = 30) | as d
        > value_of a $d | print
        30
        */
        Items items = context.items;
        Item target = items[$-1];

        context.push(items[0..$-1]);
        context.push(target);

        return target.runCommand("get", context);
    };

    commands["vars"] = function (string path, Context context)
    {
        auto escopo = context.escopo;
        auto varsList = new List([]);

        do
        {
            foreach (varName; escopo.variables.keys)
            {
                varsList.items ~= new String(varName);
            }
            escopo = escopo.parent;
        }
        while (escopo !is null);

        return context.push(varsList);
    };

    // TYPES
    commands["dict"] = function (string path, Context context)
    {
        /*
        > dict (a = 1) (b = 2) | as d
        > print ($d . a)
        1
        > print ($d . b)
        2
        */
        auto dict = new Dict();

        foreach(argument; context.items)
        {
            List l = cast(List)argument;

            Item value = l.items.back;
            l.items.popBack();

            string lastKey = l.items.back.toString();
            l.items.popBack();

            auto nextDict = dict.navigateTo(l.items);
            nextDict[lastKey] = value;
        }
        return context.push(dict);
    };
    commands["list"] = function (string path, Context context)
    {
        /*
        > set l [list 1 2 3 4]
        # l = (1 , 2 , 3 , 4)
        */
        return context.push(new List(context.items));
    };

    // set lista (a , b , c , d)
    // -> set lista [, a b c d]
    // --> set lista [list a b c d]
    commands[","] = commands["list"];

    // set pair (a = b)
    // -> set pair [= a b]
    // --> set pairt [list a b]
    commands["="] = function (string path, Context context)
    {
        auto key = context.pop();
        auto value = context.pop();
        if (context.size)
        {
            return context.error(
                "Invalid pair",
                ErrorCode.InvalidSyntax,
                ""
            );
        }
        return context.push(new Pair([key, value]));
    };
    void addVectorCommands(T, C)()
    {
        auto typeName = T.stringof ~ "_vector";

        commands[typeName] = function (string path, Context context)
        {
            auto vector = new C();

            foreach (item; context.items)
            {
                static if (__traits(isFloating, T))
                {
                    auto x = item.toFloat();
                }
                else
                {
                    auto x = item.toInt();
                }
                vector.values ~= cast(T)x;
            }

            return context.push(vector);
        };
    }
    commands["path"] = function (string name, Context context)
    {
        string path = context.pop!string;
        return context.push(new Path(path));
    };

    addVectorCommands!(byte, ByteVector);
    addVectorCommands!(float, FloatVector);
    addVectorCommands!(int, IntVector);
    addVectorCommands!(long, LongVector);
    addVectorCommands!(double, DoubleVector);

    // CONDITIONALS
    commands["if"] = function (string path, Context context)
    {
        auto isConditionTrue = context.pop!bool();
        auto thenBody = context.pop!SubProgram();

        if (isConditionTrue)
        {
            // Consume eventual "else":
            context.items();
            // Run body:
            context = context.process.run(thenBody, context.next());
        }
        // When there's no else clause:
        else if (context.size == 0)
        {
            context.exitCode = ExitCode.Success;
        }
        // else {...}
        // else if {...}
        else
        {
            auto elseWord = context.pop!string();
            if (elseWord != "else" || context.size != 1)
            {
                auto msg = "Invalid format for if/then/else clause:"
                           ~ " elseWord found was " ~ elseWord  ~ ".";
                return context.error(msg, ErrorCode.InvalidSyntax, "");
            }

            auto elseBody = context.pop!SubProgram();
            context = context.process.run(elseBody, context.next());
        }

        return context;
    };

    commands["when"] = function (string path, Context context)
    {
        /*
        If first argument is true, executes the second one and return.
        */
        auto isConditionTrue = context.pop!bool();
        auto thenBody = context.pop!SubProgram();

        if (isConditionTrue)
        {
            context = context.process.run(thenBody, context.next());
            debug {stderr.writeln("when>returnedContext.size:", context.size);}

            // Whatever the exitCode was (except Failure), we're going
            // to force a return:
            if (context.exitCode != ExitCode.Failure)
            {
                context.exitCode = ExitCode.Return;
            }
        }

        return context;
    };
    commands["default"] = function (string path, Context context)
    {
        /*
        Just like when, but there's no "first argument" to evaluate,
        it always executes the body and returns.
        */
        auto body = context.pop!SubProgram();

        context = context.process.run(body, context.next());

        // Whatever the exitCode was (except Failure), we're going
        // to force a return:
        if (context.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.Return;
        }

        return context;
    };

    // ITERATORS
    commands["transform"] = function (string path, Context context)
    {
        /*
        > range 2 | transform x {return ($x * 10)} | foreach x {print $x}
        0
        10
        20
        */
        auto varName = context.pop!string();
        auto body = context.pop!SubProgram();

        if (context.size == 0)
        {
            auto msg = "no target to transform";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        auto targets = context.items;

        auto iterator = new Transformer(
            targets, varName, body, context
        );
        context.push(iterator);
        return context;
    };
    commands["transform.inline"] = function (string path, Context context)
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
        auto body = context.pop!SubProgram();

        if (context.size == 0)
        {
            auto msg = "no target to transform";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        auto targets = context.items;

        auto iterator = new Transformer(
            targets, null, body, context
        );
        context.push(iterator);
        return context;
    };

    nameCommands["foreach"] = function (string path, Context context)
    {
        /*
        > range 2 | foreach x { print $x }
        0
        1
        2
        */
        auto argName = context.pop!string();
        auto argBody = context.pop!SubProgram();

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        uint index = 0;

        foreach (target; context.items)
        {
            debug {stderr.writeln("foreach.target:", target);}
    forLoop:
            while (true)
            {
                auto nextContext = target.next(context.next());
                debug {stderr.writeln("foreach next.exitCode:", nextContext.exitCode);}
                switch (nextContext.exitCode)
                {
                    case ExitCode.Break:
                        break forLoop;
                    case ExitCode.Failure:
                        return nextContext;
                    case ExitCode.Skip:
                        continue;
                    case ExitCode.Continue:
                        break;  // <-- break the switch, not the while.
                    default:
                        return nextContext;
                }

                loopScope[argName] = nextContext.items;

                context = context.process.run(argBody, context.next());
                debug {stderr.writeln("foreach context.exitCode:", context.exitCode);}

                if (context.exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (context.exitCode == ExitCode.Return)
                {
                    /*
                    Return propagates up into the
                    processes stack:
                    */
                    return context;
                }
                else if (context.exitCode == ExitCode.Failure)
                {
                    return context;
                }
            }
        }

        context.exitCode = ExitCode.Success;
        return context;
    };
    commands["foreach.inline"] = function (string path, Context context)
    {
        /*
        > range 2 | foreach.inline { print }
        0
        1
        2
        > range 2 | {print}
        0
        1
        2
        */
        auto argBody = context.pop!SubProgram();

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        uint index = 0;

        foreach (target; context.items)
        {
            debug {stderr.writeln("foreach.target:", target);}
    forLoop:
            while (true)
            {
                auto nextContext = target.next(context.next());
                debug {stderr.writeln("foreach next.exitCode:", nextContext.exitCode);}
                switch (nextContext.exitCode)
                {
                    case ExitCode.Break:
                        break forLoop;
                    case ExitCode.Failure:
                        return nextContext;
                    case ExitCode.Skip:
                        continue;
                    case ExitCode.Continue:
                        break;  // <-- break the switch, not the while.
                    default:
                        return nextContext;
                }

                auto bodyContext = context.next();

                // XXX: aren't we sharing the Stack?
                // Shouldn't adjust .size be enough???
                int inputSize = 0;
                foreach (item; nextContext.items.retro)
                {
                    debug {stderr.writeln("foreach.push:", item);}
                    bodyContext.push(item);
                    inputSize++;
                }

                context = context.process.run(argBody, bodyContext, inputSize);
                debug {stderr.writeln("foreach context.exitCode:", context.exitCode);}

                if (context.exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (context.exitCode == ExitCode.Return)
                {
                    /*
                    Return propagates up into the
                    processes stack:
                    */
                    return context;
                }
                else if (context.exitCode == ExitCode.Failure)
                {
                    return context;
                }
            }
        }

        context.exitCode = ExitCode.Success;
        return context;
    };

    commands["collect"] = function (string path, Context context)
    {
        /*
        > stack.push 1 2 3 4 | collect | print
        (1 2 3 4)
        */
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` needs at least one input stream";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        Items items;

        foreach (input; context.items)
        {
            while (true)
            {
                auto nextContext = input.next(context.next());
                if (nextContext.exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (nextContext.exitCode == ExitCode.Skip)
                {
                    continue;
                }
                else if (nextContext.exitCode == ExitCode.Failure)
                {
                    return nextContext;
                }
                auto x = nextContext.items;
                items ~= x;
            }
        }

        return context.push(new List(items));
    };

    commands["try"] = function (string path, Context context)
    {
        /*
        try { subcommand } { return default_value }
        */
        auto body = context.pop!SubProgram();
        SubProgram default_body = null;

        if (context.size)
        {
            default_body = context.pop!SubProgram();
        }

        context = context.process.run(body, context);
        if (context.exitCode == ExitCode.Failure)
        {
            debug {
                stderr.writeln("try on ", context.escopo.description);
                stderr.writeln(" try failure context:", context);
            }

            if (default_body)
            {
                auto error = context.pop();
                debug {stderr.writeln(" error:", error);}

                context.escopo["error"] = error;
                context.exitCode = ExitCode.Success;
                context = context.process.run(default_body, context);
            }
            else
            {
                Item errorItem = context.peek();
                if (errorItem.type == ObjectType.Error)
                {
                    auto error = cast(Erro)errorItem;

                    if (error.subject !is null)
                    {
                        if (error.subject.type == ObjectType.SystemProcess)
                        {
                            auto subject = cast(SystemProcess)(error.subject);
                            stderr.writeln("Command line: ", subject.cmdline);
                        }
                    }
                }
            }
        }

        return context;
    };
    commands["call"] = function (string path, Context context)
    {
        /*
        > call print "something"
        something
        */
        auto name = context.pop!string();

        if (context.size)
        {
            Item target = context.peek();
            context = target.runCommand(name, context);
        }
        else
        {
            context = context.program.runCommand(name, context);
        }
        debug {
            stderr.writeln("call ", name, " context:", context, "/", context.exitCode);
        }
        return context;
    };

    // Hashes
    commands["md5"] = function (string path, Context context)
    {
        string target = context.pop!string();
        char[] digest = target.hexDigest!MD5;
        return context.push(digest.to!string);
    };

    loadJsonCommands(commands);
    loadHttpCommands(commands);
    loadTimerCommands(commands);
}
