module now.nodes.dict.methods;


import now;


static this()
{
    dictMethods["set"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > dict | as d
        > set $d (x = 20)
        > print ($d . x)
        20
        */
        auto dict = cast(Dict)object;

        foreach(argument; input.popAll)
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
    dictMethods["unset"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > dict (a = 10) | as d
        > unset $d a
        */
        auto dict = cast(Dict)object;

        foreach (argument; input.popAll)
        {
            string key;
            if (argument.type != ObjectType.List)
            {
                argument = new List([argument]);
            }

            List l = cast(List)argument;

            key = l.items.back.toString();
            l.items.popBack();

            auto innerDict = dict.navigateTo(l.items, false);
            if (innerDict !is null)
            {
                innerDict.remove(key);
            }
        }

        return ExitCode.Success;
    };
    dictMethods["get"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > dict (a = 30) | as d
        > set a [get $d a]
        > print $a
        30
        */
        auto dict = cast(Dict)object;
        Items items = input.popAll;

        auto lastKey = items.back.toString();
        items.popBack();

        auto innerDict = dict.navigateTo(items, false);
        if (innerDict is null)
        {
            auto msg = "Key `" ~ to!string(items.map!(x => x.toString()).join(".")) ~ "." ~ lastKey ~ "` not found";
            throw new NotFoundException(
                input.escopo, msg, -1, dict
            );
        }

        output.push(innerDict[lastKey]);
        return ExitCode.Success;
    };
    dictMethods["."] = dictMethods["get"];
    dictMethods["keys"] = function (Item object, string path, Input input, Output output)
    {
        auto dict = cast(Dict)object;
        output.push(new List(
            cast(Items)(dict.order
            .map!(x => new String(x))
            .array)
        ));
        return ExitCode.Success;
    };
    dictMethods["pairs"] = function (Item object, string path, Input input, Output output)
    {
        auto dict = cast(Dict)object;
        foreach (key, _; dict)
        {
            auto value = dict[key];
            output.push(new Pair([new String(key), value]));
        }
        return ExitCode.Success;
    };
}
