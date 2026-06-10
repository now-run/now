module now.cli.cmd;

import now.cli;
import now;
import now.env_vars;


int main(string[] args)
{
    return cliMain(args, &cmd);
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
