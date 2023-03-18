module now.process;


import now.nodes;
import now.stack;


class Process
{
    Stack stack;

    // Process identification:
    static uint counter = 0;
    string description;
    uint index;

    this(string description)
    {
        this.description = description;

        this.stack = new Stack();
        this.index = this.counter++;
    }

    // SubProgram execution:
    Context run(SubProgram subprogram, Escopo escopo)
    {
        return run(subprogram, Context(this, escopo));
    }
    Context run(SubProgram subprogram, Context context, int inputSize=0)
    {
        foreach(pipeline; subprogram.pipelines)
        {
            context.size = 0;
            context.inputSize = inputSize;
            context = pipeline.run(context);
            debug {stderr.writeln("pipeline.run.exitCode: ", context.exitCode);}

            final switch(context.exitCode)
            {
                case ExitCode.Undefined:
                    return context.error(
                        to!string(pipeline) ~ " returned Undefined",
                        ErrorCode.InternalError,
                        ""
                    );

                case ExitCode.Success:
                    // That is the expected result from Pipelines:
                    break;

                // -----------------
                // Proc execution:
                case ExitCode.Return:
                    // Return should keep stopping
                    // processes until properly
                    // handled.
                    return context;

                case ExitCode.Failure:
                    if (context.escopo.rootCommand !is null)
                    {
                        auto escopo = context.escopo;
                        auto rootCommand = escopo.rootCommand;
                        context = rootCommand.handleEvent(context, "error");
                    }
                    /*
                    Wheter we called errorHandler or not,
                    we ARE going to exit the current
                    scope right now. The idea of
                    a errorHandler is NOT to
                    allow continuing in the
                    same scope.
                    */
                    return context;

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                case ExitCode.Skip:
                    return context;
            }
        }

        // Returns the context of the last expression:
        return context;
    }

    Context closeCMs(Context context)
    {
        auto cmList = context.escopo.contextManagers;
        bool hasFailures = false;
        foreach (contextManager; cmList)
        {
            auto closeContext = contextManager.runMethod("close", context);
            if (closeContext.exitCode == ExitCode.Failure)
            {
                /*
                Each failure when closing a context manager pushes
                a new Error into the stack. It's a specially difficult
                case to handle, so here we'll count that the user will
                try to empty the stack when handling errors.
                */
                hasFailures = true;
            }
        }
        if (hasFailures)
        {
            context.exitCode = ExitCode.Failure;
        }
        return context;
    }

    int unixExitStatus(Context context)
    {
        // Search for errors:
        if (context.exitCode == ExitCode.Failure)
        {
            Item x = context.peek();
            Erro e = cast(Erro)x;
            return e.code;
        }
        else
        {
            return 0;
        }
    }

    int finish(Context context)
    {
        debug {
            stderr.writeln("process finish: ", context);
        }
        int returnCode = unixExitStatus(context);

        if (context.exitCode == ExitCode.Failure)
        {
            auto e = context.pop!Erro();
            stderr.writeln(e);
        }
        else
        {
            foreach (item; context.items)
            {
                stdout.writeln(item.toString());
            }
        }

        return returnCode;
    }
}
