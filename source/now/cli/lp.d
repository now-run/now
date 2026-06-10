module now.cli.lp;

import now.cli;
import now;
import now.env_vars;


int main(string[] args)
{
    return cliMain(args, &lineProcessor);
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
