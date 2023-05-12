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
        return s;
    }

    ExitCode run(Escopo escopo, Output output)
    {
        return run(escopo, [], output);
    }
    ExitCode run(Escopo escopo, Items inputs, Output output)
    {
        CommandCall lastCommandCall = null;
        Item target;
        ExitCode exitCode;

        auto cmdOutput = new Output;
        if (inputs is null)
        {
            inputs = [];
        }
        else
        {
            cmdOutput.items = inputs;
        }

forLoop:
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
            catch (NowException ex)
            {
                if (!ex.printed)
                {
                    stderr.writeln("e> ", ex.typename);
                    stderr.writeln("m> ", ex.msg);
                    stderr.writeln("s> ", escopo);
                    stderr.writeln("p> ", this);
                    if (documentLineNumber)
                    {
                        stderr.writeln("l> ", documentLineNumber);
                    }
                    ex.printed = true;
                }
                throw ex;
            }
            catch (Exception ex)
            {
                stderr.writeln("m> ", ex.msg);
                stderr.writeln("s> ", escopo);
                stderr.writeln("p> ", this);
                if (documentLineNumber)
                {
                    stderr.writeln("l> ", documentLineNumber);
                }
                stderr.writeln(
                    "This is an internal error."
                );
                stderr.writeln(
                    "===== Exception ====="
                );
                stderr.writeln(ex);

                auto ex2 = new DException(
                    null,
                    ex.msg
                );
                ex2.printed = true;
                stderr.writeln(ex);
                throw ex2;
            }
            catch (object.Error ex)
            {
                stderr.writeln("m> ", ex.msg);
                stderr.writeln("s> ", escopo);
                stderr.writeln("p> ", this);
                if (documentLineNumber)
                {
                    stderr.writeln("l> ", documentLineNumber);
                }
                stderr.writeln(
                    "This is an internal error, your program may not be wrong."
                );
                stderr.writeln(
                    "===== Error ====="
                );
                stderr.writeln(ex);

                auto ex2 = new DError(
                    null,
                    ex.msg,
                );
                ex2.printed = true;
                throw ex2;
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
                    break forLoop;

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
                    lastCommandCall = commandCall;
                    break;  // break the switch and proceed in the loop
            }
        }
        // Whatever is left in cmdOutput goes to output, now:
        output.push(cmdOutput.items);

        return exitCode;
    }
}
