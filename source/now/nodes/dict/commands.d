module now.nodes.dict.commands;


import now.nodes;


static this()
{
    dictCommands["set"] = function (string path, Context context)
    {
        /*
        > dict | as d
        > set $d (x = 20)
        > print ($d . x)
        20
        */
        auto dict = context.pop!Dict();

        foreach(argument; context.items)
        {
            Pair pair = cast(Pair)argument;

            if (pair.type != ObjectType.Pair)
            {
                auto msg = "`dict." ~ path ~ "` expects pairs as arguments";
                return context.error(msg, ErrorCode.InvalidArgument, "dict");
            }

            string key = pair.items[0].toString();
            Item value = pair.items[1];

            dict[key] = value;
        }

        return context;
    };
    dictCommands["unset"] = function (string path, Context context)
    {
        /*
        > dict (a = 10) | as d
        > unset $d a
        */
        auto dict = context.pop!Dict();

        foreach (argument; context.items)
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

        return context;
    };
    dictCommands["get"] = function (string path, Context context)
    {
        /*
        > dict (a = 30) | as d
        > set a [get $d a]
        > print $a
        30
        */
        Dict dict = context.pop!Dict();
        Items items = context.items;

        auto lastKey = items.back.toString();
        items.popBack();

        auto innerDict = dict.navigateTo(items, false);
        if (innerDict is null)
        {
            auto msg = "Key `" ~ to!string(items.map!(x => x.toString()).join(".")) ~ "." ~ lastKey ~ "` not found";
            return context.error(msg, ErrorCode.NotFound, "dict");
        }

        try
        {
            return context.push(innerDict[lastKey]);
        }
        catch (Exception ex)
        {
            return context.error(ex.msg, ErrorCode.NotFound, "dict");
        }
    };
    dictCommands["."] = dictCommands["get"];
    dictCommands["keys"] = function (string path, Context context)
    {
        Dict dict = context.pop!Dict();
        return context.push(new List(
            cast(Items)(dict.order
            .map!(x => new String(x))
            .array)
        ));
    };
    dictCommands["pairs"] = function (string path, Context context)
    {
        Dict dict = context.pop!Dict();
        foreach (key; dict.order)
        {
            auto value = dict[key];
            context.push(new Pair([new String(key), value]));
        }
        return context;
    };
}
