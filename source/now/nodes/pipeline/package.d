module now.nodes.pipeline;

import core.exception : RangeError;

import now.nodes;


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

    Context run(Context context)
    {
        debug {stderr.writeln("Running Pipeline: ", this);}

        void printStatus(Context context, CommandCall command)
        {
            stderr.writeln(
                "Exception: Pipeline=", this,
                " context=", context,
                " command_call=", command
            );
        }

        foreach(index, command; commandCalls)
        {
            debug {stderr.writeln(command.name, ">run:", context.size, "/", context.inputSize);}
            try
            {
                context = command.run(context);
            }
            catch (Exception ex)
            {
                printStatus(context, command);
                return context.error(
                    "Exception: " ~ ex.to!string,
                    ErrorCode.InternalError,
                    "", null
                );
            }
            catch (RangeError ex)
            {
                printStatus(context, command);
                return context.error(
                    "RangeError: " ~ ex.to!string,
                    ErrorCode.InternalError,
                    "", null
                );
            }
            debug {stderr.writeln(command.name, ">run.exitCode:", context.exitCode);}
            debug {stderr.writeln(command.name, ">context.size:", context.size);}

            final switch(context.exitCode)
            {
                case ExitCode.Undefined:
                    return context.error(
                        to!string(command) ~ " returned Undefined",
                        ErrorCode.InternalError,
                        ""
                    );

                // -----------------
                // Proc execution:
                case ExitCode.Return:
                    // That is what a `return` command returns.
                    // Return should keep stopping SubPrograms
                    // until a procedure or a program stops.
                    // (Imagine a `return` inside some nested loops.)
                    return context;

                case ExitCode.Failure:
                    // Failures, for now, are going to be propagated:
                    return context;

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                case ExitCode.Skip:
                    // TODO: check if this will affect anything:
                    context.inputSize = context.size;
                    return context;

                // -----------------
                case ExitCode.Success:
                    context.inputSize = context.size;
                    break;
            }
        }

        context.exitCode = ExitCode.Success;
        return context;
    }
}
