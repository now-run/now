module now.nodes.command_call;


import now.nodes;


class CommandCall
{
    string name;
    Items arguments;

    this(string name, Items arguments)
    {
        this.name = name;
        this.arguments = arguments;
    }

    override string toString()
    {
        return this.name;
        /*
        return this.name
            ~ " "
            ~ arguments.map!(x => x.toString())
                .join(" ");
        */
    }

    Context evaluateArguments(Context context)
    {
        // Evaluate and push each argument, starting from
        // the last one:
        ulong realArgumentsCounter = 0;
        foreach(argument; this.arguments.retro)
        {
            /*
            Each item already pushes its evaluation
            result into the stack
            */
            debug {stderr.writeln("   evaluating argument ", argument);}
            context = argument.evaluate(context.next);

            /*
            But what if this argument is an ExecList and
            while evaluating it returned an Error???
            */
            if (context.exitCode == ExitCode.Failure)
            {
                /*
                Well, we quit imediately:
                */
                debug {stderr.writeln("   FAILURE!");}
                return context;
            }

            debug {stderr.writeln("   += ", context.size);}
            realArgumentsCounter += context.size;
        }
        context.size = cast(int)realArgumentsCounter;
        return context;
    }

    Context run(Context context)
    {
        // evaluate arguments and set proper context.size:
        auto executionContext = this.evaluateArguments(context);
        if (executionContext.exitCode == ExitCode.Failure)
        {
            return executionContext;
        }

        debug {stderr.writeln(name, ".executionContext.size:", executionContext.size);}
        if (context.inputSize)
        {
            debug {stderr.writeln(name, ".context.inputSize:", context.inputSize);}
            // `input`, when present, is always the last argument:
            executionContext.size += context.inputSize;
            executionContext.inputSize = context.inputSize;
        }
        debug {stderr.writeln(name, ".executionContext.size:", executionContext.size);}
        debug {stderr.writeln(name, ".executionContext.inputSize:", executionContext.inputSize);}

        // Inform the procedure how many arguments were passed:
        executionContext.escopo["args.count"] = new IntegerAtom(executionContext.size);

        // We consider the first argument as potentially
        // the "target", when present:
        Item target = null;
        if (executionContext.size)
        {
            target = executionContext.peek();
            return target.runCommand(name, executionContext);
        }
        else
        {
            return context.program.runCommand(name, executionContext);
        }
    }
}
