module now.commands.http;


import std.net.curl;

import now.nodes;
import now.commands.json;


auto getHttp(Items items)
{
    auto http = HTTP();

    foreach (item; items)
    {
        switch (item.type)
        {
            case ObjectType.Pair:
                auto pair = cast(Pair)item;
                auto key = pair.items[0].toString();
                auto value = pair.items[1].toString();
                http.addRequestHeader(key, value);
                break;
            case ObjectType.Dict:
            case ObjectType.List:
                auto v = ItemToJson(item);
                http.setPostData(v.to!string, "application/json");
                break;
            case ObjectType.String:
                auto s = cast(String)item;
                http.setPostData(s.toString(), "application/json");
                break;
            default:
                // TODO: handle this properly inside each command.
                throw new InvalidException("Invalid type: " ~ item.type.to!string);
        }
    }

    return http;
}


void loadHttpCommands(CommandsMap commands)
{
    commands["http.get"] = function (string path, Context context)
    {
        /*
        > http.get "http://example.com" (authorization = "bearer 1234")
        <html>...
        */
        string address = context.pop!string();
        auto http = getHttp(context.items);
        auto content = get(address, http);
        return context.push(content.to!string);
    };
    commands["http.post"] = function (string path, Context context)
    {
        /*
        > http.post "http://example.org"
        >     . authorization = "bearer 4321")
        >     . [dict (username = "John.Doe") (password = "1324")]
        */
        string address = context.pop!string();
        auto http = getHttp(context.items);
        auto content = post(address, [], http);
        return context.push(content.to!string);
    };
}
