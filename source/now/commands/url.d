module now.commands.url;


import std.uri;

import now;


void loadUrlCommands(CommandsMap commands)
{
    commands["url.encode"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            auto s = item.toString();
            output.push(s.encode());
        }
        return ExitCode.Success;
    };
    commands["url.decode"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            auto s = item.toString();
            output.push(s.decodeComponent());
        }
        return ExitCode.Success;
    };
}
