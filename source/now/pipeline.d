module now.pipeline;


import core.exception : RangeError;

import now;


class Pipeline
{
    CommandCall[] commandCalls;
    long lineIndex;

    this(CommandCall[] commandCalls, long lineIndex=0)
    {
        this.commandCalls = commandCalls;
        this.lineIndex = lineIndex;
    }

    ulong size()
    {
        return commandCalls.length;
    }

    override string toString()
    {
        auto s = to!string(commandCalls
            .map!(x => x.toString())
            .join(" | "));
        if (lineIndex)
        {
            s ~= " - line=" ~ lineIndex.to!string;
        }
        return s;
    }

    ExitCode run(Escopo escopo, Output output)
    {
        return run(escopo, output, []);
    }
    ExitCode run(Escopo escopo, Output output, Items inputs)
    {
        CommandCall lastCommandCall = null;
        Item target;
        ExitCode exitCode;

        if (inputs is null)
        {
            inputs = [];
        }

        auto cmdOutput = new Output;

        foreach(index, commandCall; commandCalls)
        {
            if (lastCommandCall !is null)
            {
                if (lastCommandCall.isTarget)
                {
                    log("-- lastCommandCall ", lastCommandCall, " is target");
                    target = cmdOutput.pop;
                }
                else
                {
                    log("-- lastCommandCall ", lastCommandCall, " is not target");
                    target = null;
                }
            }

            // Before going to the next commandCall
            // (after re-entering this loop):
            inputs = cmdOutput.items;

            // Run the command!
            cmdOutput.items.length = 0;
            try
            {
                exitCode = commandCall.run(escopo, inputs, cmdOutput, target);
            }
            catch (Exception ex)
            {
                stderr.writeln(
                    "Exception ", ex,
                    " on command ", commandCall
                );
                throw ex;
            }
            log("- Pipeline <- ", exitCode, " <- ", cmdOutput);

            final switch(exitCode)
            {
                // -----------------
                // Proc execution:
                case ExitCode.Return:
                    // That is what a `return` command returns.
                    // Return should keep stopping SubPrograms
                    // until a procedure or a program stops.
                    // (Imagine a `return` inside some nested loops.)
                    return exitCode;

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                case ExitCode.Skip:
                    return exitCode;

                /*
                Together with Return, this
                should be the most common
                exit code.
                The meaning here is simple: just
                proceed to the next command in
                this pipeline, if present.
                */
                case ExitCode.Success:
                    lastCommandCall = commandCall;
                    break;
            }
        }
        // Whatever is left in cmdOutput goes to output, now:
        output.items ~= cmdOutput.items;

        return exitCode;
    }
}
