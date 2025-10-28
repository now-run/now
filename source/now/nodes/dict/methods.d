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
        // It would make sense to return a Sequence, but the reality is
        // that `foreach`, `collect` and others won't work, since
        // each Pair is actually a List, so
        // dict (a = b) (c = d) | :: pairs | collect
        // > (a , b , c , d)
        output.push(new List(cast(Items)(dict.asPairs)));
        return ExitCode.Success;
    };
    dictMethods["run"] = function(Item object, string path, Input input, Output output)
    {
        auto dict = cast(Dict)object;
        auto subprogram = input.pop!SubProgram;

        auto escopo = input.escopo.addPathEntry("dict");

        // Escopos will inherict .values, but if the
        // dynamic array isn't initialized, then
        // it's simply NULL, so each child will initialize
        // it locally, etc.
        // Solution: make sure it is initizalied here.
        if (dict.orderedKeys.length == 0) {
            // This fails on some systems:
            // dict.values = new Item[string];
            dict.values["___noop"] = new Boolean(false);
            dict.values.remove("___noop");
        }

        escopo.values = dict.values;
        escopo.needsReordering = true;

        auto exitCode = subprogram.run(escopo, input.popAll, output);
        if (exitCode == ExitCode.Return)
        {
            exitCode = ExitCode.Success;
        }

        log("dict.run: escopo.values:", escopo.values);
        foreach (key, value; escopo.values)
        {
            dict[key] = value;
        }

        output.push(dict);

        return exitCode;
    };

    // To allow inheritance of every method, we
    // prefix all the current ones with the type name.
    foreach (k, v; dictMethods)
    {
        dictMethods["dict." ~ k] = v;
    }
}
