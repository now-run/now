module now.commands.base64;


import std.base64;

import now;


void loadBase64Commands(CommandsMap commands)
{
    commands["base64.encode"] = function (string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            ubyte[] data;
            switch (item.type)
            {
                case ObjectType.String:
                    auto s = cast(String)item;
                    data = cast(ubyte[])(s.toString());
                    break;
                case ObjectType.Name:
                    auto s = cast(Name)item;
                    data = cast(ubyte[])(s.toString());
                    break;
                default:
                    throw new SyntaxErrorException(
                        input.escopo,
                        "Invalid input for " ~ path
                        ~ ": " ~ item.type.to!string(),
                        -1,
                        item
                    );
            }
            auto result = Base64URL.encode(data);
            output.push(result.to!string);
        }
        return ExitCode.Success;
    };
    commands["base64.decode"] = function (string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            auto s = item.toString();
            ubyte[] result = Base64URL.decode(s);
            output.push(cast(string)result);
        }
        return ExitCode.Success;
    };
}
