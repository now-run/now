module now.cli;

extern(C) int isatty(int);

import std.algorithm : among;
import std.algorithm.searching : canFind, startsWith;
import std.datetime.stopwatch;
import std.file;
import std.stdio;
import std.string;

import now;
import now.env_vars;
import now.commands;


const defaultFilepath = "Nowfile";


static this()
{
    // Potential small speed-up:
    builtinCommands.rehash();
}


int main(string[] args)
{
    loadEnvVars();

    log("+ args:", args.to!string);

    NowParser parser;

    string documentPath = defaultFilepath;
    string[] documentArgs;
    string[] nowArgs;

    /*
    args[0] = now
    args[1] = commandName
    */
    for (auto argIndex = 1; argIndex < args.length; argIndex++)
    {
        auto arg = args[argIndex];
        bool hasNextArg = (argIndex + 1 < args.length);

        if (arg[0] == ':')
        {
            auto keyword = arg[1..$];

            switch (keyword)
            {
                case "stdin":
                    documentPath = stdin.name;
                    break;

                case "repl":
                case "cmd":
                    nowArgs ~= keyword;
                    break;

                case "bash-complete":
                    return bashAutoComplete(parser);

                case "help":
                    return now_help();

                case "f":
                    if (!hasNextArg)
                    {
                        stderr.writeln("Missing argument to :f");
                        return 20;
                    }
                    documentPath = args[++argIndex];
                    break;

                default:
                    stderr.writeln("Unknown command: ", keyword);
                    return 1;
            }
        }
        else
        {
            documentArgs ~= arg;
        }
    }
    log("+ nowArgs: ", nowArgs.to!string);
    log("+ documentArgs: ", documentArgs.to!string);
    log("+ documentPath: ", documentPath);

    Document document = null;
    if (documentPath.exists)
    {
        try
        {
            document = loadDocument(documentPath, documentArgs);
        }
        catch (Exception ex)
        {
            stderr.writeln(ex.msg);
            return 2;
        }
        if (document is null)
        {
            return 3;
        }
    }

    foreach (arg; nowArgs)
    {
        final switch (arg)
        {
            case "repl":
                return repl(document, documentArgs, nowArgs);
            case "cmd":
                return cmd(document, documentArgs);
        }
    }

    if (document is null)
    {
        // TODO: use a proper enum to hold return codes with names!
        return 5;
    }

    if (documentArgs.length == 0)
    {
        show_document_help(document, documentArgs);
        return 7;
    }
    string commandName = documentArgs[0];
    string[] commandArgs = documentArgs[1..$];
    if (commandName == "--help")
    {
        show_document_help(document, commandArgs);
        return 9;
    }

    return runDocument(document, commandName, documentArgs);
}


Document loadDocument(string documentPath, string[] documentArgs)
{
    NowParser parser;

    // Open and read the document file:
    parser = new NowParser(documentPath.read.to!string);

    // Parse the document:
    Document document = parser.run();
    document.sourcePath = documentPath;

    // Initialize the document:
    document.initialize(envVars);

    return document;
}


int runDocument(Document document, string commandName, string[] commandArgs)
{
    log("+ runDocument");

    // ------------------------------
    // Prepare the root scope:
    auto rootScope = new Escopo(document, "document");
    log("+ rootScope: ", rootScope);
    rootScope["env"] = envVars;
    rootScope["args"] = new List(
        cast(Items)(
            commandArgs
            .map!(x => new String(x))
            .array
        )
    );
    log("+ rootScope: ", rootScope);

    Procedure command = document.getCommand(commandName);
    if (command is null)
    {
        // Instead of trying any of the eventually existent
        // commands, just show the help text for the document.
        show_document_help(document, commandArgs);
        return 4;
    }
    log("+ command: ", command);
    log("++ commandArgs: ", commandArgs);

    // ------------------------------
    // Organize the command line arguments:
    Args args;
    KwArgs kwargs;
    /*
    commandArgs[0] = commandName
    */
    foreach (arg; commandArgs[1..$])
    {
        if (arg.length > 2 && arg[0..2] == "--")
        {
            // alfa-beta=1=2=3 -> alfa_beta = "1=2=3"
            auto pair = arg[2..$].split("=");
            auto key = pair[0].replace("-", "_");
            auto value = pair[1..$].join("=");
            kwargs[key] = new String(value);
        }
        else
        {
            args ~= new String(arg);
        }
    }
    log("  + args: ", args);
    log("  + kwargs: ", kwargs);

    // ------------------------------
    // Run the command:
    auto escopo = rootScope.addPathEntry("now");
    log("  + escopo: ", escopo);
    auto input = Input(
        escopo,
        [],
        args,
        kwargs
    );
    log("  + input: ", input);
    ExitCode exitCode;
    auto output = new Output;

    log("+ Running ", commandName, "...");
    try
    {
        exitCode = command.run(commandName, input, output, true);
    }
    catch (NowException ex)
    {
        log("+++ EXCEPTION: ", ex);
        // Global error handler:
        auto handlerString = document.get!String(
            ["document", "on.error", "body"], null
        );
        if (handlerString !is null)
        {
            log("+++ handlerString:", handlerString);
            // TODO: stop parsing SubPrograms ad-hoc!!!
            auto localParser = new NowParser(handlerString.toString());
            SubProgram handler = localParser.consumeSubProgram();

            auto newScope = escopo.addPathEntry("on.error");
            auto error = new Erro(
                ex.msg,
                ex.code,
                ex.typename,
                escopo
            );
            // TODO: do not set "error" on parent scope too.
            newScope["error"] = error;

            ExitCode errorExitCode;
            auto errorOutput = new Output;

            try
            {
                errorExitCode = handler.run(newScope, errorOutput);
            }
            catch (NowException ex2)
            {
                // return ex2.code;
                ex = ex2;
            }
            /*
            User should be able to recover gracefully from
            errors, so this output should be considered "good"...
            */
            print_output(newScope, errorOutput);
            return 0;
        }

        if (!ex.printed)
        {
            try
            {
                throw ex;
            }
            catch (ProcedureNotFoundException ex)
            {
                stderr.writeln(
                    "e> Procedure not found: ", ex.msg
                );
                return ex.code;
            }
            catch (MethodNotFoundException ex)
            {
                stderr.writeln(
                    "e> Method not found: ", ex.msg,
                    "; object: ", ex.subject
                );
                return ex.code;
            }
            catch (NotImplementedException ex)
            {
                stderr.writeln(
                    "e> Not implemented: ", ex.msg
                );
                return ex.code;
            }
            // TODO: this "statement is not reachable"???
            // stderr.writeln(ex);
        }
        return ex.code;
    }

    // TODO: what to do with `output`?
    return 0;
}


int show_document_help(Document document, string[] args)
{
    stdout.writeln(document.title);
    if (document.description)
    {
        stdout.writeln(document.description);
    }
    stdout.writeln();

    auto commands = cast(Dict)(document.data["commands"]);

    long maxLength = 16;
    foreach (commandName; document.commands.keys)
    {
        // XXX: certainly there's a Dlangier way of doing this:
        auto l = commandName.length;
        if (l > maxLength)
        {
            maxLength = l;
        }
    }
    foreach (commandName; document.commands.keys)
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
    }

    return 0;
}

int now_help()
{
    stdout.writeln("now");
    stdout.writeln("  No arguments: run ./", defaultFilepath, " if present");
    stdout.writeln("  :bash-complete - shell autocompletion");
    stdout.writeln("  :cmd <command> - run commands passed as arguments");
    stdout.writeln("  :f <file> - run a specific file");
    stdout.writeln("  :repl - enter interactive mode");
    stdout.writeln("  :stdin - read a document from standard input");
    stdout.writeln("  :help - display this help message");
    return 0;
}


int repl(Document document, string[] documentArgs, string[] nowArgs)
{
    if (document is null)
    {
        document = new Document("repl", "Read Eval Print Loop", new Dict(), new Dict());
    }

    document.initialize(envVars);

    auto escopo = new Escopo(document, "repl");
    escopo["env"] = envVars;

    stderr.writeln("Starting REPL...");

    auto istty = cast(bool)isatty(stdout.fileno);
    string line;
    string prompt = "> ";

    while (true)
    {
        if (istty)
        {
            stderr.write(prompt);
        }
        line = readln();
        if (line is null)
        {
            break;
        }
        else if (line == "R\n")
        {
            if (document.sourcePath)
            {
                auto parser = new NowParser(document.sourcePath.read.to!string);
                document = parser.run();
                stderr.writeln("Loaded ", document.sourcePath);
            }
            else
            {
                stderr.writeln("Document not found.");
            }
            continue;
        }
        else if (line == "Q\n")
        {
            break;
        }

        auto parser = new NowParser(line);
        Pipeline pipeline;
        try
        {
            pipeline = parser.consumePipeline();
        }
        catch (Exception ex)
        {
            stderr.writeln("Exception: ", ex);
            stderr.writeln("----------");
            continue;
        }
        auto output = new Output;
        // TODO: handle exceptions.
        auto exitCode = pipeline.run(escopo, output);

        // Print whatever is still in the stack:
        print_output(escopo, output);

        if (exitCode != ExitCode.Success)
        {
            stderr.writeln(exitCode.to!string);
        }
    }
    return 0;
}

int cmd(Document document, string[] documentArgs)
{
    if (document is null)
    {
        document = new Document("cmd", "Run commands passed as arguments");
        document.initialize(envVars);
    }

    auto escopo = new Escopo(document, "cmd");
    escopo["env"] = envVars;
    auto output = new Output;

    foreach (line; documentArgs)
    {
        auto parser = new NowParser(line);
        Pipeline pipeline;
        try
        {
            pipeline = parser.consumePipeline();
        }
        catch (Exception ex)
        {
            return -1;
        }

        ExitCode exitCode;
        // Reset output items array:
        output.items.length = 0;
        try
        {
            exitCode = pipeline.run(escopo, output);
        }
        catch (NowException ex)
        {
            auto error = new Erro(
                ex.msg,
                ex.code,
                ex.typename,
                escopo
            );
            stderr.writeln(error.toString());
            stderr.writeln("----------");
            return error.code;
        }

        if (exitCode != ExitCode.Success)
        {
            stderr.writeln(exitCode.to!string);
        }
    }

    // Print the output of the last command:
    print_output(escopo, output);

    return 0;
}

int bashAutoComplete(NowParser parser)
{
    Document document;

    if (parser !is null)
    {
        document = parser.run();
    }
    else
    {
        string filepath = defaultFilepath;

        if (filepath.exists)
        {
            parser = new NowParser(read(filepath).to!string);
            document = parser.run();
        }
        else
        {
            return 0;
        }
    }

    auto words = envVars["COMP_LINE"].toString().split(" ");
    string lastWord = null;
    auto ignore = 0;
    foreach (word; words.retro)
    {
        if (word.length)
        {
            lastWord = word;
            break;
        }
        ignore++;
    }
    auto n = words.length - ignore;

    document.initialize(envVars);

    if (n == 1)
    {
        stdout.writeln(document.commands.keys.join(" "));
    }
    else {
        string[] commands;
        foreach (name; document.commands.keys)
        {
            if (name.startsWith(lastWord))
            {
                commands ~= name;
            }
        }
        stdout.writeln(commands.join(" "));
    }
    return 0;
}


void print_output(Escopo escopo, Output output)
{
    log("+ print_output:", escopo, output);
    foreach (item; output.items)
    {
        debug{stderr.writeln(item.type.to!string, " ");}
        if (item.type == ObjectType.SystemProcess)
        {
            auto p = cast(SystemProcess)item;
            ExitCode nextExitCode;
            do
            {
                auto nextItems = new Output;
                nextExitCode = p.next(escopo, nextItems);
                if (nextExitCode == ExitCode.Continue)
                {
                    foreach (oItem; nextItems.items)
                    {
                        // XXX: stderr or stdout?
                        stdout.writeln(oItem.toString());
                    }
                }
            }
            while (nextExitCode == ExitCode.Continue);
            if (!nextExitCode.among(ExitCode.Success, ExitCode.Skip))
            {
                stderr.writeln(">> ", nextExitCode.to!string);
            }
        }
        else
        {
            stderr.writeln(">>> ", item);
        }
    }

}
