import std.array;
import std.file : read;
import std.stdio;
import std.string : toLower, stripRight;

import grammar;

import conv;
import exceptions;
import packages;
import nodes;
import procedures;
import process;


// Global variable:
CommandsMap commands;


// Commands:
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
    nameCommands["import"] = function (string path, Context context)
    {
        // import http
        auto packagePath = context.pop!string();

        if (!importModule(context.program, packagePath))
        {
            auto msg = "Module not found: " ~ packagePath;
            return context.error(msg, ErrorCode.NotFound, "");
        }

        return context;
    };

    // ---------------------------------------------
    subprogramCommands["run"] = function (string path, Context context)
    {
        /*
        > run { print 123 }
        123

        Specially useful in conjunction with `when`:
        > set x 1
        > run {
              when ($x == 0) {zero}
              when ($x == 1) {one}
              default {other}
          } | print
        one
        */
        auto body = context.pop!SubProgram();
        auto escopo = new Escopo(context.escopo);

        auto returnedContext = context.process.run(
            body, context.next(escopo, 0)
        );
        debug {stderr.writeln("returnedContext.size:", returnedContext.size);}
        returnedContext = context.process.closeCMs(returnedContext);
        debug {stderr.writeln("                     ", returnedContext.size);}

        context.size = returnedContext.size;
        if (returnedContext.exitCode == ExitCode.Return)
        {
            // Contain the return chain reaction:
            context.exitCode = ExitCode.Success;
        }
        else
        {
            context.exitCode = returnedContext.exitCode;
        }

        return context;
    };

    stringCommands["eval"] = function (string path, Context context)
    {
        /*
        > eval "set x 10"
        > print $x
        10
        */
        auto code = context.pop!string();

        auto parser = new Parser(code);
        SubProgram subprogram = parser.consumeSubProgram();

        context = context.process.run(subprogram, context.next());
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
    commands["to.int"] = function (string path, Context context)
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
        string name = context.pop!string();
        SubProgram body = context.pop!SubProgram();

        auto returnedContext = context.process.run(
            body, context.next()
        );
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
        auto escopo = context.escopo;

        auto cmContext = contextManager.runCommand("open", context);

        if (cmContext.exitCode == ExitCode.Failure)
        {
            return cmContext;
        }
        // XXX: can we improve this?
        auto cmList = escopo.getOrCreate!List("contextManagers");
        cmList.items ~= contextManager;

        // Make sure the stack is okay:
        context.items();
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
    commands["print.error"] = function (string path, Context context)
    {
        while(context.size) stderr.write(context.pop!string());
        stderr.writeln();
        return context;
    };

    commands["read"] = function (string path, Context context)
    {
        // read a line from std.stdin
        return context.push(new String(stdin.readln().stripRight("\n")));
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
                return context.error(msg, ErrorCode.Assertion, "");
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
        context.escopo[key] = new Sequence(context.items);

        return context;
    };
    commands["as"] = commands["set"];

    nameCommands["unset"] = function (string path, Context context)
    {
        auto firstArgument = context.pop();
        context.escopo.variables.remove(to!string(firstArgument));
        return context;
    };

    commands["vars"] = function (string path, Context context)
    {
        auto escopo = context.escopo;
        auto varsList = new SimpleList([]);

        do
        {
            foreach (varName; escopo.order)
            {
                varsList.items ~= new String(varName);
            }
            process = process.parent;
        }
        while (process !is null);

        return context.push(varsList);
    };
}
