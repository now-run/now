module now.commands.url;

import std.uri;

import now.nodes;


void loadUrlCommands(CommandsMap commands)
{
    commands["url.encode"] = function (string path, Context context)
    {
        foreach (item; context.items)
        {
            auto s = item.toString();
            context.push(s.encode());
        }
        return context;
    };
    commands["url.decode"] = function (string path, Context context)
    {
        foreach (item; context.items)
        {
            auto s = item.toString();
            context.push(s.decode());
        }
        return context;
    };


}
