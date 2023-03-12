import nodes;


// Commands:
static this()
{
    nameCommands["eq"] = function (string path, Context context)
    {
        /*
        > eq a b | print
        false
        > eq a a | print
        true
        */
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` expects at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "int");
        }

        string first = context.pop!string();
        foreach (item; context.items)
        {
            if (item.toString() != first)
            {
                return context.push(false);
            }
        }
        return context.push(true);
    };
    nameCommands["=="] = nameCommands["eq"];
    nameCommands["neq"] = function (string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` expects at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "int");
        }

        string first = context.pop!string();
        foreach (item; context.items)
        {
            if (item.toString() == first)
            {
                return context.push(false);
            }
        }
        return context.push(true);
    };
    nameCommands["!="] = nameCommands["neq"];
}
