module now.cli.repl;

extern(C) int isatty(int);

import std.file;

import now.cli;
import now;
import now.env_vars;


int main(string[] args)
{
    return cliMain(args, &repl);
}

int repl(Document document, string[] documentArgs)
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
