module now.commands.json;


import std.array;
import std.json;

import now;
import now.commands;
import now.json;


void loadJsonCommands(CommandsMap commands)
{
    commands["json.decode"] = function(string path, Input input, Output output)
    {
        foreach (arg; input.popAll)
        {
            JSONValue json = parseJSON(arg.toString());
            auto object = JsonToItem(json);
            output.push(object);
        }
        return ExitCode.Success;
    };
    commands["json.encode"] = function(string path, Input input, Output output)
    {
        foreach (arg; input.popAll)
        {
            auto json = ItemToJson(arg);
            output.push(json.toString());
        }
        return ExitCode.Success;
    };
}
