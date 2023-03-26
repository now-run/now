module now.commands.http;


import std.net.curl;

import now.nodes;
import now.commands.json;


struct Response {
    HTTP http;
    string body;
}


auto getHttp(Items items)
{
    Response response;
    response.http = HTTP();

    foreach (item; items)
    {
        switch (item.type)
        {
            case ObjectType.Pair:
                auto pair = cast(Pair)item;
                auto key = pair.items[0].toString();
                auto value = pair.items[1].toString();
                response.http.addRequestHeader(key, value);
                break;
            case ObjectType.Dict:
            case ObjectType.List:
                response.http.addRequestHeader("Content-Type", "application/json");
                response.body = ItemToJson(item).to!string();
                break;
            case ObjectType.String:
                response.http.addRequestHeader("Content-Type", "application/json");
                auto s = cast(String)item;
                response.body = s.toString();
                break;
            default:
                // TODO: handle this properly inside each command.
                throw new InvalidException("Invalid type: " ~ item.type.to!string);
        }
    }

    return response;
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
        char[] content;
        try
        {
            content = get(address, http.http);
        }
        catch (HTTPStatusException)
        {
            return context.error(
                http.http.statusLine.reason,
                http.http.statusLine.code,
                "http"
            );
        }
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
        char[] content;
        try
        {
            content = post(address, http.body, http.http);
        }
        catch (HTTPStatusException)
        {
            return context.error(
                http.http.statusLine.reason,
                http.http.statusLine.code,
                "http"
            );
        }
        return context.push(content.to!string);
    };
    commands["http.put"] = function (string path, Context context)
    {
        /*
        > http.put "http://example.org"
        >     . authorization = "bearer 4321")
        >     . [dict (username = "John.Doe") (password = "1324")]
        */
        string address = context.pop!string();
        auto http = getHttp(context.items);
        char[] content;
        try
        {
            content = put(address, http.body, http.http);
        }
        catch (HTTPStatusException)
        {
            return context.error(
                http.http.statusLine.reason,
                http.http.statusLine.code,
                "http"
            );
        }
        return context.push(content.to!string);
    };
    commands["http.delete"] = function (string path, Context context)
    {
        /*
        > http.delete "http://example.org"
        >     . authorization = "bearer 4321")
        >     . [dict (username = "John.Doe") (password = "1324")]
        */
        string address = context.pop!string();
        auto http = getHttp(context.items);
        try
        {
            del(address, http.http);
        }
        catch (HTTPStatusException)
        {
            return context.error(
                http.http.statusLine.reason,
                http.http.statusLine.code,
                "http"
            );
        }
        return context;
    };
}
