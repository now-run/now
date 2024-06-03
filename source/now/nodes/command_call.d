module now.nodes.command_call;


import now;


class CommandCall
{
    string name;
    Items args;
    Items kwargs;
    bool isTarget;
    size_t documentLineNumber;
    size_t documentColNumber;

    // For handling error locally:
    SubProgram[string] eventHandlers;

    this(string name, Items args, Items kwargs)
    {
        this.name = name;
        this.args = args;
        this.kwargs = kwargs;
        this.isTarget = false;
    }

    override string toString()
    {
        string s = this.name;
        s ~= "  " ~ args.to!string;
        s ~= "  " ~ kwargs.to!string;
        // TODO: isTarget?
        return s;
    }

    Items evaluateArguments(Escopo escopo)
    {
        Items items;

        foreach(argument; this.args)
        {
            items ~= argument.evaluate(escopo);
        }
        return items;
    }
    KwArgs evaluateKeywordArguments(Escopo escopo)
    {
        KwArgs kwargs;
        Items items;

        foreach(argument; this.kwargs)
        {
            items ~= argument.evaluate(escopo);
        }

        foreach(item; items)
        {
            if (item.type != ObjectType.Pair)
            {
                throw new InvalidArgumentsException(
                    escopo,
                    "All kwargs should be Pairs; found " ~ item.type.to!string,
                    -1,
                    item
                );
            }
            else
            {
                auto pair = cast(Pair)item;
                auto key = pair.items[0].toString;
                auto value = pair.items[1];
                kwargs[key] = value;
            }
        }
        return kwargs;
    }

    ExitCode run(Escopo escopo, Items inputs, Output output, Item target=null)
    {
        log("- CommandCall.run: ", this);
        if (isTarget)
        {
            log("-- isTarget!");
        }
        auto arguments = evaluateArguments(escopo);
        log("--- ", inputs, " | ", name, "  ", arguments);
        auto keywordArguments = evaluateKeywordArguments(escopo);

        auto input = Input(
            escopo,
            inputs,
            arguments,
            keywordArguments
        );

        try
        {
            if (target !is null)
            {
                return target.runMethod(name, input, output);
            }
            else
            {
                return escopo.document.runProcedure(name, input, output);
            }
        }
        catch (NowException ex)
        {
            auto message = ex.msg;
            // XXX: we're using .message as the error type.
            // It's weird.

            auto errorHandler = this.getEventHandler(ex.typename);
            if (errorHandler is null)
            {
                errorHandler = this.getEventHandler(message);
            }

            if (errorHandler is null)
            {
                throw ex;
            }
            else
            {
                auto errorScope = escopo.addPathEntry(
                    "error/" ~ message
                );
                errorScope["error"] = ex.toError();
                return handleEvent(
                    message, errorHandler, errorScope, output
                );
            }
        }
    }
    SubProgram getEventHandler(string eventName)
    {
        if (auto handlerPtr = (eventName in eventHandlers))
        {
            return *handlerPtr;
        }
        else if (auto handlerPtr = ("*" in eventHandlers))
        {
            return *handlerPtr;
        }
        else
        {
            return null;
        }
    }
    ExitCode handleEvent(string eventName, SubProgram handler, Escopo escopo, Output output)
    {
        log("- handleEvent: ", eventName);
        Items input = output.items;
        output.items.length = 0;
        return handler.run(escopo, input, output);
    }
}
