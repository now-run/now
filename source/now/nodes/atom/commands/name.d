module now.nodes.atom.commands.name;


import now.nodes;
import now.packages;


// Commands:
static this()
{
    nameCommands["import"] = function (string path, Context context)
    {
        // import http
        auto packagePath = context.pop!string();

        if (!importModule(context.program, packagePath))
        {
            auto msg = "Module not found: " ~ packagePath;
            return context.error(msg, ErrorCode.NotFound, "");
        }

        return context;
    };
    nameCommands["unset"] = function (string path, Context context)
    {
        auto firstArgument = context.pop();
        context.escopo.variables.remove(to!string(firstArgument));
        return context;
    };
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
