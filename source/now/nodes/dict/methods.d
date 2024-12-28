module now.nodes.dict.methods;


import now;


static this()
{
    dictMethods["set"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > dict | as d
        > set $d (x = 20)
        > print ($d . x)
        20
        */
        auto dict = cast(Dict)object;

        foreach (argument; input.popAll)
        {
            Pair pair = cast(Pair)argument;

            if (pair.type != ObjectType.Pair)
            {
                auto msg = "`dict." ~ path ~ "` expects pairs as arguments";
                throw new SyntaxErrorException(input.escopo, msg, -1, object);
            }

            string key = pair.items[0].toString();
            Item value = pair.items[1];

            dict[key] = value;
        }

        return ExitCode.Success;
    };
    dictMethods["unset"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > dict (a = 10) | as d
        > unset $d a
        */
        auto dict = cast(Dict)object;

        foreach (argument; input.popAll)
        {
            string key;
            Items keys;
            if (argument.type == ObjectType.List)
            {
                keys = (cast(List)argument).items;
            }
            else
            {
                keys = [argument];
            }

            key = keys.back.toString();
            keys.popBack();

            auto innerDict = dict.navigateTo(keys, false);
            innerDict.remove(key);
        }

        return ExitCode.Success;
    };
    dictMethods["get"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > dict (a = 30) | as d
        > o $d : get a | as value
        > print $value
        30
        */
        auto dict = cast(Dict)object;
        Items items = input.popAll;
        log("dict get kwargs:", input.kwargs);

        auto lastKey = items.back.toString;
        items.popBack;

        Dict innerDict;
        try {
            innerDict = dict.navigateTo(items, false);
            output.push(innerDict[lastKey]);
        }
        catch (NotFoundException ex)
        {
            auto defaultValue = input.kwargs.get("default", null);
            log("dict get defaultValue:", defaultValue);
            if (defaultValue is null)
            {
                ex.escopo = input.escopo;
                throw ex;
            }
            else {
                output.push(defaultValue);
                return ExitCode.Success;
            }
        }

        return ExitCode.Success;
    };
    dictMethods["."] = dictMethods["get"];
    dictMethods["keys"] = function(Item object, string path, Input input, Output output)
    {
        auto dict = cast(Dict)object;
        output.push(new List(
            cast(Items)(dict.order
            .map!(x => new String(x))
            .array)
        ));
        return ExitCode.Success;
    };
    dictMethods["pairs"] = function(Item object, string path, Input input, Output output)
    {
        auto dict = cast(Dict)object;
        output.push(cast(Items)(dict.asPairs));
        return ExitCode.Success;
    };
    dictMethods["run"] = function(Item object, string path, Input input, Output output)
    {
        auto dict = cast(Dict)object;
        auto subprogram = input.pop!SubProgram;

        auto escopo = input.escopo.addPathEntry("dict");
        escopo.values = dict.values;
        escopo.needsReordering = true;

        auto exitCode = subprogram.run(escopo, input.popAll, output);
        if (exitCode == ExitCode.Return)
        {
            exitCode = ExitCode.Success;
        }

        dict.values = escopo.values;
        dict.needsReordering = true;

        return exitCode;
    };

    // To allow inheritance of every method, we
    // prefix all the current ones with the type name.
    foreach (k, v; dictMethods)
    {
        dictMethods["dict." ~ k] = v;
    }
}
