module now.commands.http;

import std.array : replace;
import std.net.curl;

import now;
import now.json;


struct Response {
    HTTP http;
    string body;
}


auto getHttp(Items items, Item[string] kwargs=null)
{
    Response response;
    response.http = HTTP();

    bool verifySsl = true;

    if (kwargs !is null)
    {
        auto verifyFlagPtr = ("verify_ssl" in kwargs);
        if (verifyFlagPtr !is null)
        {
            verifySsl = (*verifyFlagPtr).toBool;
        }
    }

    response.http.verifyPeer = verifySsl;
    response.http.verifyHost = verifySsl;

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
                // TODO: handle this properly inside each command...?
                throw new InvalidException(
                    null,
                    "Invalid type: " ~ item.type.to!string,
                    -1,
                    item
                );
        }
    }

    return response;
}


void loadHttpCommands(CommandsMap commands)
{
    commands["url"] = function (string path, Input input, Output output)
    {
        /*
        > url "https://{domain}"
              . (domain = "example.com")
        >     . [dict (limit = 100) (offset = 0)]
        https://example.com?limit=100&offset=0
        */
        string address = input.pop!string();
        string[] query_params;

        foreach (item; input.popAll)
        {
            switch (item.type)
            {
                case ObjectType.Pair:
                    auto pair = cast(Pair)item;
                    auto key = pair.items[0].toString;
                    auto value = pair.items[1].toString;
                    address = address.replace("{" ~ key ~ "}", value);
                    break;

                case ObjectType.Dict:
                    auto dict = cast(Dict)item;
                    foreach (key; dict.order)
                    {
                        auto value = dict[key].toString;
                        // TODO: URL-encode all this
                        query_params ~= key ~ "=" ~ value;
                    }
                    break;
                default:
            }
        }
        if (query_params.length)
        {
            address ~= "?" ~ query_params.join("&");
        }

        output.push(address);
        return ExitCode.Success;
    };
    commands["http.get"] = function (string path, Input input, Output output)
    {
        /*
        > http.get "http://example.com" (authorization = "bearer 1234")
        <html>...
        */
        string address = input.pop!string();

        auto http = getHttp(input.popAll, input.kwargs);
        char[] content;
        try
        {
            content = get(address, http.http);
        }
        catch (HTTPStatusException)
        {
            throw new HTTPException(
                input.escopo,
                http.http.statusLine.reason,
                http.http.statusLine.code,
            );
        }
        output.push(content.to!string);
        return ExitCode.Success;
    };
    commands["http.post"] = function (string path, Input input, Output output)
    {
        /*
        > http.post "http://example.org"
        >     . (authorization = "bearer 4321")
        >     . [dict (username = "John.Doe") (password = "1324")]
        */
        string address = input.pop!string();
        auto http = getHttp(input.popAll, input.kwargs);
        char[] content;
        try
        {
            content = post(address, http.body, http.http);
        }
        catch (HTTPStatusException)
        {
            throw new HTTPException(
                input.escopo,
                http.http.statusLine.reason,
                http.http.statusLine.code,
            );
        }
        output.push(content.to!string);
        return ExitCode.Success;
    };
    commands["http.put"] = function (string path, Input input, Output output)
    {
        /*
        > http.put "http://example.org"
        >     . authorization = "bearer 4321")
        >     . [dict (username = "John.Doe") (password = "1324")]
        */
        string address = input.pop!string();
        auto http = getHttp(input.popAll, input.kwargs);
        char[] content;
        try
        {
            content = put(address, http.body, http.http);
        }
        catch (HTTPStatusException ex)
        {
            // XXX: maybe we should add the original exception
            // to the new one...
            throw new HTTPException(
                input.escopo,
                http.http.statusLine.reason,
                http.http.statusLine.code,
            );
        }
        output.push(content.to!string);
        return ExitCode.Success;
    };
    commands["http.delete"] = function (string path, Input input, Output output)
    {
        /*
        > http.delete "http://example.org"
        >     . authorization = "bearer 4321")
        >     . [dict (username = "John.Doe") (password = "1324")]
        */
        string address = input.pop!string();
        auto http = getHttp(input.popAll, input.kwargs);
        try
        {
            del(address, http.http);
        }
        catch (HTTPStatusException)
        {
            throw new HTTPException(
                input.escopo,
                http.http.statusLine.reason,
                http.http.statusLine.code,
            );
        }
        return ExitCode.Success;
    };
}
