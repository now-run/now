module now.commands.iterators;


import now;
import now.commands;


// Ranges
class IntegerRange : Item
{
    long start = 0;
    long limit = 0;
    long step = 1;
    long current = 0;
    bool silent = false;

    this(long limit)
    {
        this.limit = limit;
        this.type = ObjectType.Range;
        this.typeName = "integer_range";
    }
    this(long start, long limit)
    {
        this(limit);
        this.current = start;
        this.start = start;
    }
    this(long start, long limit, long step)
    {
        this(start, limit);
        this.step = step;
    }

    override string toString()
    {
        return
            "range.integer("
            ~ to!string(start)
            ~ ","
            ~ to!string(limit)
            ~ ")";
    }

    override ExitCode next(Escopo escopo, Output output)
    {
        ExitCode exitCode;
        long value = current;
        if (value > limit)
        {
            exitCode = ExitCode.Break;
        }
        else
        {
            if (!silent)
            {
                output.push(value);
            }
            exitCode = ExitCode.Continue;
        }
        current += step;
        return exitCode;
    }
}


// Iterators for "transform":
class Transformer : Item
{
    Items targets;
    size_t targetIndex = 0;
    SubProgram body;
    Escopo escopo;
    string varName;
    bool empty;

    this(
        Items targets,
        string varName,
        SubProgram body,
        Escopo escopo
    )
    {
        this.type = ObjectType.Range;
        this.typeName = "transformer";

        this.targets = targets;
        this.varName = varName;
        this.body = body;
        this.escopo = escopo;
    }

    override string toString()
    {
        return "Transformer";
    }

    override ExitCode next(Escopo escopo, Output output)
    {
        /*
        `transform` accept more than one targets, that is,
        more than one things it's going to consume from.
        */
        auto target = targets[targetIndex];
        auto nextOutput = new Output;
        auto exitCode = target.next(escopo, nextOutput);

        switch (exitCode)
        {
            case ExitCode.Break:
                targetIndex++;
                if (targetIndex < targets.length)
                {
                    return next(escopo, output);
                }
                goto case;
            case ExitCode.Skip:
                return exitCode;
            case ExitCode.Continue:
                break;
            default:
                throw new IteratorException(
                    escopo,
                    to!string(target)
                    ~ ".next returned "
                    ~ to!string(exitCode)
                );
        }

        if (varName)
        {
            escopo[varName] = nextOutput.items;
        }
        else
        {
            foreach (item; nextOutput.items)
            {
                output.push(item);
            }
        }

        auto execExitCode = body.run(escopo, output);

        switch(execExitCode)
        {
            case ExitCode.Return:
            case ExitCode.Success:
                execExitCode = ExitCode.Continue;
                break;

            default:
                break;
        }
        return execExitCode;
    }
}
