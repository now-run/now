module now.commands.base64;

import std.base64;

import now.nodes;


void loadBase64Commands(CommandsMap commands)
{
    commands["base64.encode"] = function (string path, Context context)
    {
        foreach (item; context.items)
        {
            ubyte[] data;
            switch (item.type)
            {
                case ObjectType.String:
                    auto s = cast(String)item;
                    data = cast(ubyte[])(s.toString());
                    break;
                case ObjectType.Name:
                    auto s = cast(NameAtom)item;
                    data = cast(ubyte[])(s.toString());
                    break;
                case ObjectType.Vector:
                    if (item.typeName == "byte_vector")
                    {
                        auto s = cast(ByteVector)item;
                        data = cast(ubyte[])(s.values);
                        break;
                    }
                    goto default;
                default:
                    return context.error(
                        "Invalid input for " ~ path
                        ~ ": " ~ item.type.to!string(),
                        ErrorCode.InvalidArgument,
                        ""
                    );
            }
            auto result = Base64URL.encode(data);
            context.push(result.to!string);
        }
        return context;
    };
    commands["base64.decode"] = function (string path, Context context)
    {
        foreach (item; context.items)
        {
            auto s = item.toString();
            ubyte[] result = Base64URL.decode(s);
            context.push(cast(string)result);
        }
        return context;
    };
}
