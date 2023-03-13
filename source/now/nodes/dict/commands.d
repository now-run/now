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
            List l = cast(List)argument;

            if (l.items.length < 2)
            {
                auto msg = "`dict." ~ path ~ "` expects lists with at least 2 items";
                return context.error(msg, ErrorCode.InvalidArgument, "dict");
            }

            Item value = l.items.back;
            l.items.popBack();

            string lastKey = l.items.back.toString();
            l.items.popBack();

            auto nextDict = dict.navigateTo(l.items);
            nextDict[lastKey] = value;
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
    dictCommands["extract"] = function (string path, Context context)
    {
        /*
        > dict (a = 30) | as d
        > set a [extract $d a]
        > print $a
        30
        */
        Dict dict = context.pop!Dict();
        Items items = context.items;

        auto lastKey = items.back.toString();
        items.popBack();

        auto innerDict = dict.navigateTo(items, false);
        debug {stderr.writeln(" innerDict:", innerDict);}
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
    dictCommands["."] = dictCommands["extract"];
}
