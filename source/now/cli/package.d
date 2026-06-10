module now.cli;

import std.algorithm : among;
import std.file;
import std.path : baseName;
import std.stdio;
import std.string;

import now;

import now.env_vars;
import now.commands;


const DEFAULT_NOWFILE_PATH = "Nowfile";


int cliMain(string[] args, int function(Document, string[]) handler)
{
    /**
    Function to be called by all forms of CLI binaries.
    **/

    // Potential small speed-up:
    // XXX: let's do it only when we're actually calling commands.
    // builtinCommands.rehash();

    loadEnvVars();

    log("+ args:", args.to!string);

    string documentPath = DEFAULT_NOWFILE_PATH;
    string[] documentArgs;

    string programName = args[0];
    envVars["program_path"] = new String(programName);
    envVars["program_name"] = new String(programName.baseName);

    /*
    args[0] = now
    args[1] = commandName?
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

    return handler(document, documentArgs);
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

int now_help()
{
    stdout.writeln("now");
    stdout.writeln("  No arguments: run ./", DEFAULT_NOWFILE_PATH, " if present");
    stdout.writeln("  :f <file> - run a specific file");
    stdout.writeln("  :help - display this help message");
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
