module now.cli.main;

import std.algorithm.searching : startsWith;
import std.string;

import now.cli;
import now;
import now.env_vars;


int main(string[] args)
{
    return cliMain(args, &runDocument);
}

int runDocument(Document document, string[] documentArgs)
{
    log("+ runDocument");

    if (document is null)
    {
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
    foreach (arg; commandArgs[0..$])
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
