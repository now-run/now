module now.nodes.command_call;


import std.algorithm.searching : startsWith;

import now;


struct NamedSubProgram
{
    string name;
    SubProgram subprogram;
}


class CommandCall
{
    string name;
    Items args;
    Items kwargs;
    size_t documentLineNumber;
    size_t documentColNumber;
    Pipeline pipeline;

    // For handling error locally:
    SubProgram[string] eventHandlers;

    this(string name, Items args, Items kwargs)
    {
        this.name = name;
        this.args = args;
        this.kwargs = kwargs;
    }
    this(string name, Items args, Items kwargs, NamedSubProgram[] eventHandlers)
    {
        this(name, args, kwargs);

        foreach (pair; eventHandlers)
        {
            auto k = pair.name;
            auto v = pair.subprogram;
            this.eventHandlers[k] = v;
        }
    }

    override string toString()
    {
        string s;
        s ~= this.name;
        s ~= "  " ~ args.to!string;
        s ~= "  " ~ kwargs.to!string;
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
            if (item.type == ObjectType.Pair)
            {
                auto pair = cast(Pair)item;
                auto key = pair.key.toString;
                kwargs[key] = pair.value;
            }
            else if (item.type == ObjectType.Dict)
            {
                /*
                dict (a = b) (c = d)
                print "x" -- $dict
                */
                auto dict = cast(Dict)item;
                foreach (pair; dict.asPairs)
                {
                    kwargs[pair.key.toString] = pair.value;
                }
            }
            else
            {
                throw new InvalidArgumentsException(
                    escopo,
                    "All kwargs should be Pairs; found " ~ item.type.to!string,
                    -1,
                    item
                );
            }
        }
        return kwargs;
    }

    ExitCode run(Escopo escopo, Items inputs, Output output)
    {
        log("- CommandCall.run: ", this);
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
            return escopo.errorHandler(this.pipeline, {
                return escopo.document.runProcedure(name, input, output);
            });
        }
        catch (NowException ex)
        {
            log(">>> CommandCall <", this.name, "> NowException <", ex.classe, ">");
            log("    eventHandlers: ", this.eventHandlers);
            auto eventHandler = this.getEventHandler(ex.classe);
            if (eventHandler is null)
            {
                eventHandler = this.getEventHandler(ex.code.to!string);
            }

            if (eventHandler is null)
            {
                throw ex;
            }
            else
            {
                auto errorScope = escopo.addPathEntry(
                    "event/" ~ ex.classe
                );
                // XXX: should we use only "event"?
                errorScope["error"] = ex.toError();
                errorScope["event"] = ex.toError();
                return handleEvent(
                    ex.classe, eventHandler, errorScope, output
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
            log("     no eventHandlers found for <", eventName, ">");
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
