module now.cli;

extern(C) int isatty(int);

import core.thread : Thread;
import std.algorithm : among;
import std.algorithm.searching : canFind, startsWith;
import std.datetime.stopwatch;
import std.file;
import std.path : baseName;
import std.stdio;
import std.string;

import now;
import now.httpserver;
import now.library_server;
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

    string documentPath = defaultFilepath;
    string[] documentArgs;
    string[] nowArgs;

    string programName = args[0];
    envVars["program_path"] = new String(programName);
    envVars["program_name"] = new String(programName.baseName);

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

                // Commands to be called laters goes here.
                case "cmd":
                case "dump":
                case "http":
                case "lib":
                case "lp":
                case "repl":
                case "watch":
                    nowArgs ~= keyword;
                    break;

                case "bash-complete":
                    return bashAutoComplete();

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
            stderr.writeln("Error while loading document ", documentPath, ":");
            stderr.writeln(ex);
            return 2;
        }
        if (document is null)
        {
            return 3;
        }
    }

    // Don't forget to add these to the first switch/case!
    foreach (arg; nowArgs)
    {
        final switch (arg)
        {
            case "cmd":
                return cmd(document, documentArgs);
            case "dump":
                return dump(document, documentArgs);
            case "http":
                return httpServer(document, documentArgs);
            case "lib":
                return libraryServer(document, documentArgs);
            case "lp":
                return lineProcessor(document, documentArgs);
            case "repl":
                return repl(document, documentArgs, nowArgs);
            case "watch":
                return watch(document, documentArgs);
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
    auto rootScope = new Escopo(document, commandName);
    log("+ rootScope: ", rootScope);
    rootScope["env"] = envVars;
    rootScope["cl_args"] = new List(
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
        stderr.writeln(
            "Command not found: " ~ commandName
        );
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
        if (arg.length > 2 && arg.startsWith("--"))
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
    auto input = Input(
        rootScope,
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
        exitCode = errorPrinter({
            return command.run(commandName, input, output, true);
        });
    }
    // TODO: all this should be implemented by Document class, right?
    catch (NowException ex)
    {
        log("+++ EXCEPTION: ", ex);
        // Global error handler:
        if (document.errorHandler !is null)
        {
            auto newScope = rootScope.addPathEntry("on.error");
            auto error = ex.toError();
            // TODO: do not set "error" on parent scope too.
            newScope["error"] = error;

            ExitCode errorExitCode;
            auto errorOutput = new Output;

            try
            {
                errorExitCode = document.errorHandler.run(newScope, errorOutput);
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
            printOutput(newScope, errorOutput);
            return 0;
        }

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
        catch (NowException ex)
        {
            return ex.code;
        }
        catch (Exception ex)
        {
            return 1;
        }
    }

    // TODO: what to do with `output`?
    return 0;
}


void show_document_help(Document document, string[] args)
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
}

int now_help()
{
    stdout.writeln("now");
    stdout.writeln("  No arguments: run ./", defaultFilepath, " if present");
    stdout.writeln("  :bash-complete - shell autocompletion");
    stdout.writeln("  :cmd <command> - run commands passed as arguments");
    stdout.writeln("  :dump - prints the document as interpreted");
    stdout.writeln("  :f <file> - run a specific file");
    stdout.writeln("  :repl - enter interactive mode");
    stdout.writeln("  :stdin - read a document from standard input");
    stdout.writeln("  :watch - watch-and-execute a file containing a subprogram");
    stdout.writeln("  :help - display this help message");
    return 0;
}


int repl(Document document, string[] documentArgs, string[] nowArgs)
{
    if (document is null)
    {
        document = new Document("repl", "Read Eval Print Loop");
    }

    document.initialize(envVars);

    auto escopo = new Escopo(document, "repl");
    escopo["env"] = envVars;

    stderr.writeln("Starting REPL...");

    auto istty = cast(bool)isatty(stdout.fileno);
    string line;
    string lastLine;
    string prompt = "> ";

    while (true)
    {
        if (istty)
        {
            stderr.write(prompt);
        }
        lastLine = line;
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
        // TODO: make it a proper command
        else if (line == "!\n")
        {
            line = lastLine;
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
        ExitCode exitCode;
        try
        {
            exitCode = errorPrinter({
                return pipeline.run(escopo, output);
            });
        }
        catch (NowException ex)
        {
            auto error = ex.toError;
            stderr.writeln(error.toString());
            // return error.code;
        }

        // Print whatever is still in the stack:
        printOutput(escopo, output);

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

        while (!parser.eof)
        {
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
                exitCode = errorPrinter({
                    return pipeline.run(escopo, output);
                });
            }
            catch (NowException ex)
            {
                auto error = ex.toError;
                stderr.writeln(error.toString());
                return error.code;
            }

            if (exitCode != ExitCode.Success)
            {
                stderr.writeln(exitCode.to!string);
            }
        }
    }

    // Print the output of the last command:
    printOutput(escopo, output);

    return 0;
}
int lineProcessor(Document document, string[] documentArgs)
{
    if (document is null)
    {
        document = new Document("lp", "Now as a Line Processor");
        document.initialize(envVars);
    }

    auto escopo = new Escopo(document, "lp");
    Items inputs = [new PathFileRange(stdin)];
    auto output = new Output;

    ExitCode exitCode;

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

        // Reset output before running a new pipeline:
        output.items.length = 0;
        try
        {
            exitCode = errorPrinter({
                return pipeline.run(escopo, inputs, output);
            });
        }
        catch (NowException ex)
        {
            auto error = ex.toError;
            stderr.writeln(error.toString());
            return error.code;
        }

        if (exitCode != ExitCode.Success)
        {
            stderr.writeln(exitCode.to!string);
        }

        // Prepare for next command:
        inputs = output.items;
    }

    // `| {print}`
    auto printCommand = new CommandCall("print", [], []);
    auto printer = new CommandCall(
        "foreach.inline",
        [new SubProgram([new Pipeline([printCommand])])], []
    );

    auto printerOutput = new Output;
    try
    {
        exitCode = errorPrinter({
            return printer.run(escopo, output.items, printerOutput);
        });
    }
    catch (NowException ex)
    {
        auto error = ex.toError;
        stderr.writeln(error.toString());
        return error.code;
    }

    if (exitCode != ExitCode.Success)
    {
        stderr.writeln(exitCode.to!string);
    }

    // Print the output of the last command:
    printOutput(escopo, printerOutput);

    return 0;
}
int dump(Document document, string[] documentArgs)
{
    if (document is null)
    {
        return 1;
    }

    stdout.writeln("# Variables");
    foreach (key, value; document)
    {
        stdout.writeln(key, ": ", value);
    }

    stdout.writeln("# Procedures");
    foreach (name; document.procedures)
    {
        stdout.writeln(name);
    }
    stdout.writeln("# Commands");
    foreach (name; document.commands)
    {
        stdout.writeln(name);
    }
    return 0;
}
int watch(Document document, string[] documentArgs)
{
    if (document is null)
    {
        document = new Document("watch", "Watch for changes in a file");
        document.initialize(envVars);
    }

    if (documentArgs.length == 0)
    {
        throw new Exception("You must define one file to be watched.");
    }
    string filepath = documentArgs[0];

    // Sometimes we call Now with proper arguments
    // but create the file later, so here we wait
    // until the file exists:
    while (!filepath.exists)
    {
        Thread.sleep(2500.msecs);
    }

    auto watchedFiles = [filepath];
    if (document.sourcePath !is null)
    {
        watchedFiles ~= document.sourcePath;
    }

    auto lastModified = filepath.timeLastModified;
    foreach (path; watchedFiles)
    {
        auto t = path.timeLastModified;
        if (t > lastModified)
        {
            lastModified = t;
        }
    }

    auto escopo = new Escopo(document, "watch");
    escopo["env"] = envVars;
    auto output = new Output;

    while (filepath.exists) {
        auto parser = new NowParser(filepath.read.to!string);
        auto subprogram = parser.consumeSubProgram();

        bool hasError = false;
        try
        {
            auto exitCode = errorPrinter({
                return subprogram.run(escopo, output);
            });
        }
        catch (Exception ex)
        {
            hasError = true;
        }

        if (!hasError)
        {
            printOutput(escopo, output);
        }
        stdout.flush;

        // Hold the loop while the file is not changed:
nextIter:
        while (true)
        {
            Thread.sleep(2500.msecs);
            foreach (path; watchedFiles)
            {
                auto t = path.timeLastModified;
                if (t > lastModified)
                {
                    lastModified = t;
                    stderr.writeln("=== ", path, " ", t);
                    // XXX: kinda weird handling, here.
                    // We actually have only 2 possible files...
                    if (path == document.sourcePath)
                    {
                        document = loadDocument(
                            document.sourcePath,
                            documentArgs
                        );
                        escopo = new Escopo(document, "watch");
                        escopo["env"] = envVars;
                    }
                    break nextIter;
                }
            }
        }
    }
    return 0;
}


int bashAutoComplete()
{
    Document document;

    if (!defaultFilepath.exists)
    {
        return 0;
    }

    auto parser = new NowParser(defaultFilepath.read.to!string);
    document = parser.run();
    document.initialize(envVars);

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


void printOutput(Escopo escopo, Output output)
{
    log("+ printOutput:", escopo, output);
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
