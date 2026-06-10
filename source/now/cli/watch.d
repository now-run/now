module now.cli.watch;

import core.thread : Thread;
import std.datetime.stopwatch;
import std.file;

import now.cli;
import now;
import now.env_vars;


int main(string[] args)
{
    return cliMain(args, &watch);
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
        stderr.writeln("You must define one file to be watched.");
        return 40;
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
