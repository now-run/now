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

    ExitCode run(Escopo escopo, Items inputs, Output output, Item target=null)
    {
        log("- CommandCall.run: ", this);
        if (isTarget)
        {
            log("-- isTarget!");
        }
        auto arguments = evaluateArguments(escopo);
        log("--- ", inputs, " | ", name, "  ", arguments);
        // TODO:
        // auto keywordArguments = evaluateKeywordArguments(escopo);
        KwArgs keywordArguments;

        auto input = Input(
            escopo,
            inputs,
            arguments,
            keywordArguments
        );

        if (target !is null)
        {
            return target.runMethod(name, input, output);
        }
        else
        {
            auto exitCode = escopo.document.runProcedure(name, input, output);
            return exitCode;
        }
    }
}
