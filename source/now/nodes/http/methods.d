module now.nodes.http.methods;


import std.net.curl;
import now;


static this()
{
    httpMethods["get"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > o $connection : get (authorization = "bearer 1234")
        <html>...
        */
        auto connection = cast(Http)object;
        output.push(connection.perform(HTTP.Method.get, input));
        return ExitCode.Success;
    };
    httpMethods["post"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > o $connection : post "http://example.org"
        >     . (authorization = "bearer 4321")
        >     . [dict (username = "John.Doe") (password = "1324")]
        */
        auto connection = cast(Http)object;
        output.push(connection.perform(HTTP.Method.post, input));
        return ExitCode.Success;
    };
    httpMethods["put"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > o $connection : put "http://example.org"
        >     . authorization = "bearer 4321")
        >     . [dict (username = "John.Doe") (password = "1324")]
        */
        auto connection = cast(Http)object;
        output.push(connection.perform(HTTP.Method.put, input));
        return ExitCode.Success;
    };
    httpMethods["delete"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > o $connection : delete "http://example.org"
        >     . authorization = "bearer 4321")
        >     . [dict (username = "John.Doe") (password = "1324")]
        */
        auto connection = cast(Http)object;
        output.push(connection.perform(HTTP.Method.del, input));
        return ExitCode.Success;
    };

    httpMethods["close"] = function (Item object, string path, Input input, Output output)
    {
        auto http = cast(Http)object;
        return ExitCode.Success;
    };

    // ======================================================

    httpResponseMethods["status"] = function (Item object, string path, Input input, Output output)
    {
        auto response = cast(HttpResponse)object;
        output.push(cast(long)response.parent.http.statusLine.code);
        return ExitCode.Success;
    };
    httpResponseMethods["content"] = function (Item object, string path, Input input, Output output)
    {
        auto response = cast(HttpResponse)object;
        output.push(cast(string)response.content);
        return ExitCode.Success;
    };
}
