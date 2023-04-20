module now.commands.iterators;


import now.commands;
import now.nodes;


// Iterators for "transform":
class Transformer : Item
{
    Items targets;
    size_t targetIndex = 0;
    SubProgram body;
    Context context;
    string varName;
    bool empty;

    this(
        Items targets,
        string varName,
        SubProgram body,
        Context context
    )
    {
        this.type = ObjectType.Range;
        this.typeName = "range";

        this.targets = targets;
        this.varName = varName;
        this.body = body;
        this.context = context;
    }

    override string toString()
    {
        return "transform";
    }

    override Context next(Context context)
    {
        auto target = targets[targetIndex];
        auto targetContext = target.next(context);

        switch (targetContext.exitCode)
        {
            case ExitCode.Break:
                targetIndex++;
                if (targetIndex < targets.length)
                {
                    return next(context);
                }
                goto case;
            case ExitCode.Failure:
            case ExitCode.Skip:
                return targetContext;
            case ExitCode.Continue:
                break;
            default:
                return context.error(
                    to!string(target)
                    ~ ".next returned "
                    ~ to!string(targetContext.exitCode),
                    ErrorCode.Invalid,
                    ""
                );
        }

        int inputSize = 0;
        if (varName)
        {
            context.escopo[varName] = targetContext.items;
        }
        else
        {
            foreach (item; targetContext.items.retro)
            {
                debug {stderr.writeln("transform> pushing:", item);}
                context.push(item);
                inputSize++;
            }
        }

        auto execContext = context.process.run(body, context, inputSize);

        switch(execContext.exitCode)
        {
            case ExitCode.Return:
            case ExitCode.Success:
                execContext.exitCode = ExitCode.Continue;
                break;

            default:
                break;
        }
        return execContext;
    }
}
