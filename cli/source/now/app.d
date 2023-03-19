module now.cli;


import std.algorithm.searching : canFind;
import std.array : array, join, replace, split;
import std.datetime.stopwatch;
import std.file;
import std.process : environment;
import std.range : retro;
import std.stdio;
import std.string;

// import now.lib;
import now.commands;
import now.context;
import now.conv;
import now.grammar;
import now.nodes;
import now.process;

int main(string[] args)
{
    Parser parser;

    auto argumentsList = new List(
        cast(Items)args.map!(x => new String(x)).array
    );
    auto envVars = new Dict();
    foreach(key, value; environment.toAA())
    {
        envVars[key] = new String(value);
    }

    debug
    {
        auto sw = StopWatch(AutoStart.no);
        sw.start();
    }

    // Potential small speed-up:
    commands.rehash;

    string filepath = "program.now";
    string subCommandName = null;
    Procedure subCommand = null;
    int programArgsIndex;

    if (args.length >= 2)
    {
        subCommandName = args[1];
        programArgsIndex = 2;
    }
    else
    {
        programArgsIndex = 1;
    }

    debug {stderr.writeln("subCommandName:", subCommandName);}

    if (subCommandName.canFind(":"))
    {
        auto parts = subCommandName.split(":");
        debug {stderr.writeln("  parts:", parts);}
        auto prefix = parts[0];
        debug {stderr.writeln("  prefix:", prefix);}

        // ":stdin".split(":") -> ["", "stdin"];
        if (prefix == "")
        {
            auto keyword = parts[1];
            switch (keyword)
            {
                case "stdin":
                    parser = new Parser(stdin.byLine.join("\n").to!string);
                    filepath = null;
                    subCommandName = null;
                    break;
                case "help":
                    return now_help();
                default:
                    stderr.writeln("Unknown command: ", filepath);
                    return 1;
            }
        }
    }
    if (subCommandName is null && args.length >= 3)
    {
        subCommandName = args[2];
        programArgsIndex = 3;
    }

    if (parser is null)
    {
        try
        {
            parser = new Parser(read(filepath).to!string);
        }
        catch (FileException ex)
        {
            stderr.writeln(
                "Error ",
                ex.errno, ": ",
                ex.msg
            );
            return ex.errno;
        }
    }

    debug
    {
        sw.stop();
        stderr.writeln(
            "Code was loaded in ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }

    debug {sw.start();}

    Program program;
    try
    {
        program = parser.run();
    }
    catch (Exception ex)
    {
        stderr.writeln(ex.to!string);
        return -1;
    }
    program.initialize(commands, envVars);

    debug
    {
        sw.stop();
        stderr.writeln(
            "Semantic analysis took ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }

    debug {stderr.writeln(">>> subCommandName:", subCommandName);}

    if (subCommandName == "--help")
    {
        return show_program_help(filepath, args, program);
    }


    // The scope:
    program["args"] = argumentsList;
    program["env"] = envVars;

    // Find the right subCommand:
    if (subCommandName !is null)
    {
        auto subCommandPtr = (subCommandName in program.subCommands);
        if (subCommandPtr !is null)
        {
            subCommand = *subCommandPtr;
        }
        else
        {
            stderr.writeln("Command ", subCommandName, " not found.");
            return 2;
        }
    }
    else
    {
        // Instead of trying any of the eventually existent
        // commands, just show the help text for the program.
        show_program_help(filepath, args, program);
        return 4;
    }

    // The main Process:
    auto process = new Process("main");

    // Start!
    debug {sw.start();}

    auto escopo = new Escopo(program);
    auto context = Context(process, escopo);

    // Push all command line arguments into the stack:
    /*
    [commands/default]
    parameters {
        name { type string }
        times {
            type integer
            default 1
        }
    }
    ---
    $ now program.now Fulano
    Hello, Fulano!

    No need to cast, here. Leave it to
    the BaseCommand/Procedure class.
    */
    foreach (arg; args[programArgsIndex..$].retro)
    {
        debug {stderr.writeln(" arg:", arg);}
        if (arg.length > 2 && arg[0..2] == "--")
        {
            auto pair = arg[2..$].split("=");
            // alfa-beta -> alfa_beta
            auto key = pair[0].replace("-", "_");

            // alfa-beta=1=2=3 -> alfa_beta = "1=2=3"
            auto value = pair[1..$].join("=");

            auto p = new Parser(value);

            context.push(new Pair([
                new String(key),
                p.consumeItem()
            ]));
        }
        else
        {
            context.push(arg);
        }
    }

    debug {
        stderr.writeln("cli stack: ", context.process.stack);
    }
    // Run the main process:
    /*
    Procedure.run is going to create a new scope first thing, so
    we don't have to worry about the program itself being the scope.
    */
    context = subCommand.run(subCommandName, context);

    debug {
        stderr.writeln(" end of program; context: ", context);
    }
    if (context.exitCode == ExitCode.Failure)
    {
        // Global error handler:
        auto handlerString = program.get!String(
            ["program", "on.error", "body"],
            delegate (Dict d) {
                return null;
            }
        );
        if (handlerString !is null)
        {
            auto localParser = new Parser(handlerString.toString());
            SubProgram handler = localParser.consumeSubProgram();

            // XXX: can't it be the SAME scope???
            auto newScope = new Escopo(context.escopo);

            // Avoid calling on.error recursively:
            newScope.rootCommand = null;

            auto error = context.peek();
            if (error.type == ObjectType.Error)
            {
                newScope["error"] = error;
            }

            auto newContext = Context(context.process, newScope);
            context = context.process.run(handler, newContext);
        }
    }

    int returnCode = process.finish(context);

    debug
    {
        sw.stop();
        stderr.writeln(
            "Program was run in ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }

    return returnCode;
}

int show_program_help(string filepath, string[] args, Program program)
{
    auto programName = program.get!String(
        ["program", "name"],
        delegate (Dict d) {
            if (filepath)
            {
                return new String(filepath);
            }
            else
            {
                return new String("-");
            }
        }
    );
    stdout.writeln(programName.toString());

    auto programDescription = program.get!String(
        ["program", "description"],
        delegate (Dict d) {
            return null;
        }
    );
    if (programDescription)
    {
        stdout.writeln(programDescription.toString());
    }
    stdout.writeln();

    auto programDict = cast(Dict)program;
    auto commands = cast(Dict)(programDict["commands"]);

    long maxLength = 16;
    foreach (commandName; program.subCommands.keys)
    {
        // XXX: certainly there's a Dlangier way of doing this:
        auto l = commandName.length;
        if (l > maxLength)
        {
            maxLength = l;
        }
    }
    foreach (commandName; program.subCommands.keys)
    {
        auto command = cast(Dict)(commands[commandName]);

        string description = "?";
        if (auto descriptionPtr = ("description" in command.values))
        {
            description = (*descriptionPtr).toString();
        }
        stdout.writeln(
            " ", (commandName ~ " ").leftJustify(maxLength, '-'),
            "> ", description
        );

        auto parameters = cast(Dict)(command["parameters"]);
        foreach (parameter; parameters.order)
        {
            auto info = cast(Dict)(parameters[parameter]);
            auto type = info["type"];
            auto defaultPtr = ("default" in info.values);
            string defaultStr = "";
            if (defaultPtr !is null)
            {
                auto d = *defaultPtr;
                defaultStr = " = " ~ d.toString();
            }
            stdout.writeln("    ", parameter, " : ", type, defaultStr);
        }
        if (parameters.order.length == 0)
        {
            // stdout.writeln("    (no parameters)");
        }
    }

    return 0;
}

int now_help()
{
    stdout.writeln("now");
    stdout.writeln("  - No arguments: run ./program.now");
    stdout.writeln("  :stdin - reads a program from standard input");
    stdout.writeln("  :help - displays this help message");
    return 0;
}
