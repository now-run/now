module now.pipeline;


import core.exception : RangeError;

import now;


class Pipeline
{
    CommandCall[] commandCalls;
    size_t documentLineNumber;
    size_t documentColNumber;

    this(CommandCall[] commandCalls)
    {
        this.commandCalls = commandCalls;
        foreach (cc; commandCalls)
        {
            cc.pipeline = this;
        }
    }

    ulong size()
    {
        return commandCalls.length;
    }

    override string toString()
    {
        return commandCalls
            .map!(x => x.toString())
            .join(" | ").to!string;
    }

    ExitCode run(Escopo escopo, Output output)
    {
        return run(escopo, [], output);
    }
    ExitCode run(Escopo escopo, Items inputs, Output output)
    {
        ExitCode exitCode;

        if (inputs is null)
        {
            inputs = [];
        }
        auto cmdOutput = new Output;
        cmdOutput.items = inputs;

forLoop:
        foreach (index, commandCall; commandCalls)
        {
            // Before going to the next commandCall
            // (after re-entering this loop):
            inputs = cmdOutput.items;

            // Run the command!
            cmdOutput.items.length = 0;

            exitCode = escopo.errorHandler(this, {
                return commandCall.run(escopo, inputs, cmdOutput);
            });
            log("- Pipeline <- ", exitCode, " <- ", cmdOutput);

            final switch(exitCode)
            {
                // -----------------
                // Proc execution:

                // -----------------
                // That is what a `return` command returns.
                // Return should keep stopping SubPrograms
                // until a procedure or a program stops.
                // (Imagine a `return` inside some nested loops.)
                case ExitCode.Return:
                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                case ExitCode.Skip:
                    break forLoop;

                /*
                Together with Return, this
                should be the most common
                exit code.
                The meaning here is simple: just
                proceed to the next command in
                this pipeline, if present.
                */
                case ExitCode.Success:
                    break;  // break THE SWITCH and proceed in the loop
            }
        }
        // Whatever is left in cmdOutput goes to output, now:
        output.push(cmdOutput.items);

        return exitCode;
    }
}
