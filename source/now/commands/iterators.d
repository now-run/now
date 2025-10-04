module now.commands.iterators;

import core.thread : Thread;
import core.time : msecs;

import now;
import now.commands;


class Loop : Item
{
    long i = 0;
    this()
    {
        this.type = ObjectType.Range;
        this.typeName = "loop";
    }
    override string toString()
    {
        return "<loop: i=" ~ i.to!string ~ ">";
    }
    override ExitCode next(Escopo escopo, Output output)
    {
        return ExitCode.Continue;
    }
}
class WaitLoop : Loop
{
    long wait = 0;
    long i = 0;
    this(long wait)
    {
        super();
        this.wait = wait;
    }
    override ExitCode next(Escopo escopo, Output output)
    {
        if (i++ == 0)
        {
            return ExitCode.Continue;
        }
        else
        {
            Thread.sleep(wait.msecs);
            return ExitCode.Continue;
        }
    }
}

// Ranges
class IntegerRange : Item
{
    long start = 0;
    long limit = 0;
    long step = 1;
    long current = 0;

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
            output.push(value);
            exitCode = ExitCode.Continue;
        }
        current += step;
        return exitCode;
    }
}

class TakeRange : Item
{
    long n = 0;
    long current = 0;
    long rangeIndex = 0;
    Items ranges;

    this(long n, Items ranges)
    {
        this.n = n;
        this.ranges = ranges.map!(x => x.range()).array;
        this.type = ObjectType.Range;
        this.typeName = "take_range";
    }

    override string toString()
    {
        // TODO: show the type of this.range too.
        return
            "range.take("
            ~ to!string(n)
            ~ ")";
    }

    override ExitCode next(Escopo escopo, Output output)
    {
        current++;
        if (current > n)
        {
            return ExitCode.Break;
        }

        auto range = ranges[rangeIndex];
        auto exitCode = range.next(escopo, output);
        if (exitCode == ExitCode.Break)
        {
            rangeIndex++;
            if (rangeIndex >= ranges.length)
            {
                return ExitCode.Break;
            }
            else
            {
                return ExitCode.Skip;
            }
        }
        else
        {
            return exitCode;
        }
    }
}



// Iterators for "transform":
class Transformer : Item
{
    Items targets;
    size_t targetIndex;
    size_t currentListIndex;
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

        this.varName = varName;
        this.body = body;
        this.escopo = escopo;

        // Get all ranges from targets:
        foreach (target; targets)
        {
            this.targets ~= target.range();
        }
    }

    override string toString()
    {
        return "Transformer";
    }

    Output executeNextTarget(Escopo escopo, Output output)
    {
        if (targetIndex >= targets.length)
        {
            return null;
        }

        auto target = targets[targetIndex];

        auto nextOutput = new Output;
        auto exitCode = target.next(escopo, nextOutput);

        switch (exitCode)
        {
            // XXX: we keep calling this method recursively...
            case ExitCode.Break:
                targetIndex++;
                goto case;
            case ExitCode.Skip:
                return executeNextTarget(escopo, output);

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

        return nextOutput;
    }

    override ExitCode next(Escopo escopo, Output output)
    {
        /*
        `transform` accept more than one targets, that is,
        more than one things it's going to consume from.
        */
        auto nextOutput = executeNextTarget(escopo, output);
        if (nextOutput is null)
        {
            return ExitCode.Break;
        }

        if (varName)
        {
            log("- Transformer ", varName, " <- ", nextOutput.items);
            escopo[varName] = nextOutput.items;
            nextOutput.items = [];
        }

        auto execExitCode = body.run(escopo, nextOutput.items, output);
        log("-- Transformer.body.exitCode: ", execExitCode, " <- ", output.items);

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

class Filter : Transformer
{
    this(Items targets, SubProgram body, Escopo escopo)
    {
        super(targets, null, body, escopo);
        this.typeName = "filter";
    }

    override ExitCode next(Escopo escopo, Output output)
    {
        auto nextOutput = executeNextTarget(escopo, output);
        if (nextOutput is null)
        {
            return ExitCode.Break;
        }
        auto items = nextOutput.items;

        auto filterOutput = new Output;
        auto execExitCode = body.run(escopo, items, filterOutput);
        log("-- Filter.body.exitCode: ", execExitCode, " <- ", filterOutput.items);

        // TODO: handle execExitCode!

        /*
        Filter will actually implement an `any` command:
        if any of the values returned are true, then it's
        a continue.
        */
        foreach (filterItem; filterOutput.items)
        {
            if (filterItem.toBool == true)
            {
                output.push(items);
                return ExitCode.Continue;
            }
        }

        return ExitCode.Skip;
    }
}
