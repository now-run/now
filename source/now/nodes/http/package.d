module now.nodes.http;


import std.net.curl;
import now;
import now.json;


MethodsMap httpMethods;
MethodsMap httpResponseMethods;


class Http : Item
{
    string url;
    HTTP http;

    this(String url)
    {
        this.type = ObjectType.Http;
        this.typeName = "http";
        this.methods = httpMethods;

        this.url = url.to!string;
        this.http = HTTP(this.url);
    }

    // ------------------
    // Conversions
    override string toString()
    {
        string s = "http connection to " ~ this.url;
        return s;
    }

    // ------------------
    HttpResponse perform(HTTP.Method method, Input input)
    {
        auto requestBody = getBody(input.popAll);

        http.contentLength = requestBody.length;
        http.onSend = (void[] data)
        {
            auto m = cast(void[])requestBody;
            size_t len = m.length > data.length ? data.length : m.length;
            if (len == 0) return len;
            data[0..len] = m[0..len];
            requestBody = requestBody[len..$];
            return len;
        };

        ubyte[] content;
        // TODO: allow user to define his own callbacks.
        http.onReceive = (ubyte[] data) {
            content ~= data;
            return data.length;
        };

        http.method = method;
        try {
            http.perform();
        }
        catch (HTTPStatusException)
        {
            throw new HTTPException(
                input.escopo,
                http.statusLine.reason,
                http.statusLine.code,
            );
        }
        return new HttpResponse(this, content);
    }

    string getBody(Items items)
    {
        string body;

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
                    http.addRequestHeader("Content-Type", "application/json");
                    body = ItemToJson(item).to!string();
                    break;
                case ObjectType.String:
                    auto s = cast(String)item;
                    body = s.toString();
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

        return body;
    }
}

class HttpResponse : Item
{
    Http parent;
    ubyte[] content;

    this(Http parent, ubyte[] content)
    {
        this.type = ObjectType.HttpResponse;
        this.typeName = "http_response";
        this.methods = httpResponseMethods;

        this.parent = parent;
        this.content = content;
    }

    // ------------------
    // Conversions
    override string toString()
    {
        string s = "http response to " ~ parent.url;
        return s;
    }
}
