module now.httpserver;

import core.thread : Fiber;
import std.algorithm : among, filter, remove;
import std.algorithm.searching : canFind, findSplit, startsWith;
import std.array : array, join, split;
import std.conv : to;
import std.datetime;
import std.file : exists, read;
import std.path : buildPath;
import std.stdio : stderr, writefln;
import std.string : stripRight;
import std.range : front, popFront;
import std.regex : matchFirst;
import std.socket : InternetAddress, Socket, SocketException, SocketSet, TcpSocket;
import std.string : replace, toLower;
import std.uri : decode;

import now;
import now.cli;
import now.env_vars;
import now.json;

const auto DEFAULT_IP_BLOCK_TIME = "300";
const auto DEFAULT_PORT = 5000;
const auto DEFAULT_STATIC_DIR = "./static";
const auto DEFAULT_STATIC_PATH = "/static/";
const auto DEFAULT_FORBIDDEN_WORDS = "wp-admin,.+\\.php,cgi-bin";
const auto MAX_CONNECTIONS = 1024;
const auto SELECT_TIMEOUT = 50;
const auto RECEIVE_BUFFER_SIZE = 256;
const auto MAX_REQUEST_SIZE = 1024 * 1024;


alias strings = string[];

string static_files_dir;
string static_files_path;
strings forbiddenWords;
long[string] blockedIPs;
long ipBlockTime;

class Client : Fiber
{
    Document document;
    Socket socket;

    this(Document document, Socket socket)
    {
        this.document = document;
        this.socket = socket;
        stderr.writeln(
            "---------- New client: ",
            socket.remoteAddress().toString(),
            " ----------"
        );
        super(&safe_run);
    }

    void safe_run()
    {

        try
        {
            run();
        }
        catch (Exception ex) {
            stderr.writeln(ex);
            return;
        }
    }

    void run()
    {
        log("> run");
        char[RECEIVE_BUFFER_SIZE] buf;
        char[] request;

        auto remoteAddress = socket.remoteAddress.toString;

        while (buf.length < MAX_REQUEST_SIZE)
        {
            auto datLength = socket.receive(buf[]);

            if (datLength == Socket.ERROR)
            {
                log("Connection error.");

                return;
            }
            else if (datLength != 0)
            {
                request ~= buf[0..datLength];
                if (buf[0..datLength].canFind("\r\n\r\n"))
                {
                    log(
                        "All headers consumed. Bytes read: ",
                        datLength
                    );
                    break;
                }
                else if (datLength < RECEIVE_BUFFER_SIZE)
                {
                    log(
                        "bytes read: ",
                        datLength
                    );
                    break;
                }
                else
                {
                    log(
                        "Waiting for more. Bytes read: ",
                        datLength
                    );
                }
            }
            else
            {
                try
                {
                    // if the connection closed due to an error, remoteAddress() could fail
                    log(
                        "Connection closed: ",
                        remoteAddress
                    );
                }
                catch (SocketException)
                {
                    log("Connection closed.");
                }

                return;
            }
        }
        Fiber.yield();

        auto data = (cast(string) request);
        log(
            "Request size: ",
            data.length
        );
        log("data:\n", data);
        log("-----");

        // ----------------------------
        auto parts = data.split("\r\n");
        string firstLine = parts.front;
        parts.popFront;

        // ----------------------------
        // Process headers
        strings[string] headers;
        string[string] cookies;
        string body;
        foreach (part; parts)
        {
            if (part.length == 0)
            {
                parts.popFront;
                body = parts.join("\r\n");
                break;
            }
            else
            {
                auto split = part.findSplit(": ");
                parts.popFront;

                auto key = split[0].toLower.replace("-", "_");
                auto value = split[2];

                if (key == "cookie")
                {
                    // can come in many parts: a=b; c=d; e=f
                    auto cookieParts = value.split("; ");
                    foreach (cpart; cookieParts)
                    {
                        auto s = cpart.split("=");
                        cookies[s[0]] = s[1..$].join("=");
                    }
                }
                else
                {
                    headers[key] ~= value;
                }
            }
        }

        log(">> ", firstLine);

        // ----------------------------
        // Process first line
        // POST /users/1234-5678 HTTP/1.1
        parts = firstLine.split(" ");
        if (parts.length != 3)
        {
            socket.send("HTTP/1.1 400 Bad Request\r\n");
            return;
        }
        auto verb = parts[0].toLower;

        auto rawPath = parts[1];
        string path;
        string[string] queryParams;
        auto rawPathParts = rawPath.split("?");
        if (rawPathParts.length > 2)
        {
            socket.send("HTTP/1.1 400 Bad Request\r\n");
            socket.send("\r\n");
            socket.send("Invalid path.\r\n");
            return;
        }
        else if (rawPathParts.length == 2)
        {
            path = rawPathParts[0];
            foreach (pair; rawPathParts[1].split("&"))
            {
                auto pairParts = pair.split("=");
                if (pairParts.length == 1)
                {
                    queryParams[pairParts[0]] = null;
                }
                else
                {
                    queryParams[pairParts[0]] = pairParts[1..$]
                        .join("=")
                        .replace("%40", "@")  // so weird...
                        .decode;
                }
            }
        }
        else
        {
            path = rawPath;
        }

        auto protocol = parts[2];
        if (!protocol.startsWith("HTTP/1"))
        {
            socket.send("HTTP/1.1 400 Bad Request\r\n");
            return;
        }

        log(verb, " ", path, " ", protocol);

        long contentLength = body.length;
        bool isChunked = false;
        auto remoteIP = remoteAddress.split(':')[0];
        foreach (key, values; headers)
        {
            log("h: ", key, "=", values);

            if (key == "content_length")
            {
                contentLength = values[0].to!long;
            }
            else if (key == "transfer_encoding") {
                // (transfer_encoding = chunked) (expect = 100-continue)
                isChunked = (values[0] == "chunked");
            }
            else if (key == "x_real_ip")
            {
                remoteIP = values[0];
            }
        }
        log("body:\n", body);
        log("-----\n");
        stderr.writeln("remoteIP=", remoteIP);

        log("blockedIPs=", blockedIPs);

        auto untilRef = (remoteIP in blockedIPs);
        if (untilRef !is null) {
            long until = *untilRef;

            SysTime today = Clock.currTime();
            long now = today.toUnixTime!long();

            auto diff = until - now;

            if (diff > 0)
            {
                socket.send("HTTP/1.1 429 Too Many Requests\r\n");
                socket.send("\r\n");
                socket.send("Retry-After: " ~ diff.to!string ~ "\r\n");
                return;
            }
            else
            {
                stderr.writeln("Unblocked: ", remoteIP);
                blockedIPs.remove(remoteIP);
            }
        }



        // ----------------------------
        // Read the rest of the body if necessary
        // TODO: consider that the body could be both binary or Unicode...
        if (isChunked) {
            /*
            3\r\n
            xyz\r\n
            4\r\n
            abcd\r\n
            0\r\n
            \r\n
            */
            log("DATA IS CHUNKED!");
            foreach (i; 0..1000)
            {
                //Fiber.yield();
                auto datLength = socket.receive(buf[]);

                if (datLength == Socket.ERROR)
                {
                    log("Connection error.");
                    return;
                }
                else if (datLength != 0)
                {
                    log("> chunk=", buf[0..datLength]);
                    /*
                    chunk=a\r\n
                    123456789a\r\n
                    */
                    auto chunkParts = buf[0..datLength].to!string.split("\n");
                    auto sizeString = chunkParts[0].stripRight("\r");
                    auto rest = chunkParts[1..$].join("\n").stripRight("\r\n");
                    log(">> size=", sizeString, "; rest=", rest, ";;");
                    body ~= rest;

                    if (sizeString == "0")
                    {
                        break;
                    }
                }
                else
                {
                    try
                    {
                        // if the connection closed due to an error, remoteAddress() could fail
                        log(
                            "Connection closed: ",
                            remoteAddress
                        );
                    }
                    catch (SocketException)
                    {
                        log("Connection closed.");
                    }
                    break;
                }
            }
            log(">> chunked body=", body);
        }
        else if (body.length < contentLength)
        {
            log(
                "Body length (",
                body.length,
                ") is less than declared Content-Length (",
                contentLength,
                ")"
            );

            while (body.length < contentLength)
            {
                Fiber.yield();
                auto datLength = socket.receive(buf[]);

                if (datLength == Socket.ERROR)
                {
                    log("Connection error.");
                    return;
                }
                else if (datLength != 0)
                {
                    body ~= buf[0..datLength];
                }
                else
                {
                    try
                    {
                        // if the connection closed due to an error, remoteAddress() could fail
                        log(
                            "Connection closed: ",
                            remoteAddress
                        );
                    }
                    catch (SocketException)
                    {
                        log("Connection closed.");
                    }
                    break;
                }
            }
        }
        Fiber.yield();

        // ----------------------------
        // Serve static files
        // Do not force the user to implement it, it's usually unsafe.
        // Also: serve "text" directly from the Nowfile.
        log("verb=%s; path=%s", verb, path);
        if (verb == "get" && path.startsWith(static_files_path))
        {
            auto relativePath = path[(static_files_path.length)..$];
            log("static file relative path: ", relativePath);
            if (relativePath.canFind("../"))
            {
                socket.send("HTTP/1.1 400 Bad Request\r\n");
                socket.send("\r\n");
                socket.send("Invalid static file path.\r\n");
                return;
            }
            string filePath = buildPath(static_files_dir, relativePath); 
            if (!filePath.exists)
            {
                socket.send("HTTP/1.1 404 Not Found\r\n");
                socket.send("\r\n");
                socket.send("Static file not found.\r\n");
                return;
            }
            socket.send("HTTP/1.1 200 Ok\r\n");
            socket.send("\r\n");
            socket.send(filePath.read());
            return;
        }

        //
        auto escopo = new Escopo(document, path);

        // ----------------------------
        // Get the response from Now
        // XXX: will we allow for "/users/:id/friends"?
        // Or force users to go with "/users/friends?id=x"
        // Solution: "id is always the last part".
        // So, if the route isn't found, try trimmimg the last part.
        // (And delivering the ID as `$id`?
        auto pathParts = path.split("/");
        string[] commandNames = [
            path.replace("/", ":") ~ ":" ~ verb,
            path.replace("/", ":"),
        ];
        log("pathParts: ", pathParts);
        if (pathParts.length >= 3)
        {
            auto lastPart = pathParts.back;
            pathParts.popBack;
            auto pathMinusTail = pathParts.join(":");
            commandNames ~= pathMinusTail ~ ":" ~ verb;
            commandNames ~= pathMinusTail;
            escopo["object_id"] = new String(lastPart);
        }

        escopo["verb"] = new String(verb);

        escopo["path"] = new String(path);
        auto queryParamsDict = new Dict();
        foreach (key, value; queryParams)
        {
            queryParamsDict[key] = new String(value);
        }
        escopo["query_parameters"] = queryParamsDict;

        auto headersDict = new Dict();
        foreach (key, value; headers)
        {
            if (value.length == 0)
            {
                headersDict[key] = new String("");
            }
            else if (value.length == 1)
            {
                headersDict[key] = new String(value[0]);
            }
            else
            {
                headersDict[key] = new List(
                    cast(Item[])
                    value
                    .map!(x => (new String(x)))
                    .array
                );
            }
        }
        escopo["headers"] = headersDict;

        auto cookiesDict = new Dict();
        foreach (key, value; cookies)
        {
            cookiesDict[key] = new String(value);
        }
        escopo["cookies"] = cookiesDict;

        // content_type = application/x-www-form-urlencoded
        // body: field1=value1&field2=value2
        escopo["body"] = new String(body);
        if (headers.get("content_type", [""])[0] == "application/x-www-form-urlencoded")
        {
            auto dataDict = new Dict();
            auto pairs = body.split("&");
            foreach (pair; pairs)
            {
                auto x = pair.split("=");
                dataDict[x[0]] = new String(
                    x[1..$]
                    .join("=")
                    .replace("%40", "@")  // so weird...
                    .decode
                );
            }
            escopo["data"] = dataDict;
        }

        Args args;
        KwArgs kwargs;
        auto input = Input(
            escopo,
            [],
            args,
            kwargs
        );
        log("  + input: ", input);
        ExitCode exitCode;
        auto output = new Output;

        Fiber.yield();

        NowException exception = null;
        long errorCode = 500;
        foreach (commandName; commandNames)
        {
            auto name = "http" ~ commandName;
            log("trying: ", name);

            input.reset;

            try
            {
                exitCode = document.runProcedure(name, input, output, true);
                // stderr.writeln(" -> ", exitCode);
            }
            catch (ProcedureNotFoundException ex)
            {
                // stderr.writeln(" not found");
                exception = ex;
                errorCode = 404;
                // printException(exception);
                continue;
            }
            catch (NowException ex)
            {
                stderr.writeln(" ", ex);
                exception = ex;
                // printException(exception);
                break;
            }

            // If didn't break before, it's a success.
            exception = null;
            break;
        }
        if (exception !is null)
        {
            printException(exception);

            auto error = exception.toError;
            auto errorString = error.toString();

            if (errorCode == 404)
            {
                stderr.writeln("Not found: ", path);
                socket.send("HTTP/1.1 404 Not Found\r\n");

                foreach (part; path.split('/')[1..$])
                {
                    foreach (word; forbiddenWords)
                    {
                        if (part.matchFirst("^" ~ word ~ "$"))
                        {
                            SysTime today = Clock.currTime();
                            long now = today.toUnixTime!long();
                            blockedIPs[remoteIP] = now + ipBlockTime;
                            stderr.writeln(
                                "BLOCKED ", remoteIP,
                                " because '", part, "'/'", word,
                                "' until ", now + ipBlockTime
                            );
                            break;
                        }
                    }
                }
            }
            else
            {
                stderr.writeln(
                    "Server error: ", path, " / ",
                    errorCode.to!string, " ", errorString
                );
                socket.send("HTTP/1.1 " ~ errorCode.to!string ~ " Server Error\r\n");
            }
            socket.send("\r\n");
            socket.send(errorString);
            return;
        }

        // TODO: could we use the exitCode to something???

        Fiber.yield();

        // ----------------------------
        // Send the response to the socket.
        long statusCode = 200;
        string statusMsg;
        string[string] responseHeaders;
        string responseBody = "";

        foreach (item; output.items)
        {
            switch (item.type)
            {
                case ObjectType.Pair:
                    auto pair = cast(Pair) item;
                    auto value = pair.value;

                    switch (pair.key.type)
                    {
                        case ObjectType.Name:
                            switch (pair.key.toString)
                            {
                                case "status_code":
                                    statusCode = pair.value.toLong;
                                    break;
                                case "status_message":
                                    statusMsg = pair.value.toString;
                                    break;
                                default:
                                    stderr.writefln(
                                        "Unknown directive: ",
                                        pair.value.toString
                                    );
                            }
                            break;
                        default:
                            responseHeaders[pair.key.toString] = pair.value.toString;
                    }
                    break;

                case ObjectType.Dict:
                    responseBody = ItemToJson(item).toString;
                    break;

                case ObjectType.String:
                    responseBody = item.toString;
                    break;

                default:
                    log("TODO: handle type ", item.type);
            }
        }

        if (statusMsg is null)
        {
            long x = statusCode / 100;
            switch (x)
            {
                case 1:
                case 2:
                    statusMsg = "Ok";
                    break;
                case 3:
                    statusMsg = "Redirection";
                    break;
                case 4:
                    statusMsg = "Client Error";
                    break;
                case 5:
                    statusMsg = "Server Error";
                    break;
                default:
                    statusMsg = "Unknown";
            }
        }

        socket.send(
            "HTTP/1.1 "
            ~ statusCode.to!string ~ " "
            ~ statusMsg
            ~ "\r\n"
        );
        foreach (key, value; responseHeaders)
        {
            socket.send(key);
            socket.send(":");
            socket.send(value);
            socket.send("\r\n");
        }
        socket.send("\r\n");
        socket.send(responseBody);

        log("\tProcessed.");
    }
}


int httpServer(Document document, string[] documentArgs)
{
    log("+ httpServer");

    // ------------------------------
    // Prepare the root scope:
    auto rootScope = new Escopo(document, "httpserver");
    log("+ rootScope: ", rootScope);
    rootScope["env"] = envVars;

    string commandName = "http:init";

    // ------------------------------
    // Organize the command line arguments:
    Args args;
    KwArgs kwargs;
    kwargs["port"] = new Integer(DEFAULT_PORT);
    kwargs["static_files_dir"] = new String(DEFAULT_STATIC_DIR);
    kwargs["static_files_path"] = new String(DEFAULT_STATIC_PATH);
    kwargs["forbidden_words"] = new String(DEFAULT_FORBIDDEN_WORDS);
    kwargs["ip_block_time"] = new String(DEFAULT_IP_BLOCK_TIME);
    foreach (arg; documentArgs)
    {
        if (arg.startsWith("--"))
        {
            // alfa-beta=1=2=3 -> alfa_beta = "1=2=3"
            auto pair = arg[2..$].split("=");
            auto key = pair[0].replace("-", "_");
            auto value = pair[1..$].join("=");
            kwargs[key] = new String(value);
        }
        else
        {
            args ~= new String(arg);
        }
    }
    ushort port = cast(ushort) kwargs["port"].toLong;
    static_files_dir = kwargs["static_files_dir"].toString;
    static_files_path = kwargs["static_files_path"].toString;
    forbiddenWords = kwargs["forbidden_words"].toString.split(",").array;
    ipBlockTime = kwargs["ip_block_time"].toLong;

    log("  + args: ", args);
    log("  + kwargs: ", kwargs);
    log("  + port: ", port);

    // ------------------------------
    // Run the command:
    auto input = Input(
        rootScope,
        [],
        args,
        kwargs
    );
    log("  + input: ", input);
    ExitCode exitCode;
    auto output = new Output;

    log("+ Running ", commandName, "...");
    try
    {
        exitCode = errorPrinter({
            return document.runProcedure(commandName, input, output);
        });
    }
    // TODO: all this should be implemented by Document class, right?
    catch (NowException ex)
    {
        log("+++ EXCEPTION: ", ex);
        // Global error handler:
        if (document.errorHandler !is null)
        {
            auto newScope = rootScope.addPathEntry("on.error");
            auto error = ex.toError();
            // TODO: do not set "error" on parent scope too.
            newScope["error"] = error;

            ExitCode errorExitCode;
            auto errorOutput = new Output;

            try
            {
                errorExitCode = document.errorHandler.run(newScope, errorOutput);
            }
            catch (NowException ex2)
            {
                // return ex2.code;
                ex = ex2;
            }
            /*
            User should be able to recover gracefully from
            errors, so this output should be considered "good"...
            */
            printOutput(newScope, errorOutput);
            return 0;
        }

        try
        {
            throw ex;
        }
        catch (ProcedureNotFoundException ex)
        {
            stderr.writeln(
                "e> Procedure not found: ", ex.msg
            );
            return ex.code;
        }
        catch (MethodNotFoundException ex)
        {
            stderr.writeln(
                "e> Method not found: ", ex.msg,
                "; object: ", ex.subject
            );
            return ex.code;
        }
        catch (NotImplementedException ex)
        {
            stderr.writeln(
                "e> Not implemented: ", ex.msg
            );
            return ex.code;
        }
        catch (NowException ex)
        {
            return ex.code;
        }
        catch (Exception ex)
        {
            return 1;
        }
    }

    return serverLoop(document, port);
}

int serverLoop(Document document, ushort port)
{
    auto listener = new TcpSocket();
    assert(listener.isAlive);
    listener.blocking = false;
    listener.bind(new InternetAddress(port));
    // TODO: make it configurable:
    listener.listen(32);
    log("Listening on port ", port);

    // + 1 == room for listener
    auto socketSet = new SocketSet(MAX_CONNECTIONS + 1);
    Client[] clients;

    while (true)
    {
        // Prepare socketSet
        socketSet.reset();
        socketSet.add(listener);
        Client[] listeningClients;

        foreach (client; clients.filter!(x => x.socket.isAlive))
        {
            socketSet.add(client.socket);
            listeningClients ~= client;
        }

        // SELECT!
        auto messages = Socket.select(socketSet, null, null, dur!"msecs"(SELECT_TIMEOUT));

        if (messages)
        {
            // --------------------------
            // Handle new messages
            foreach (index, client; listeningClients)
            {
                if (socketSet.isSet(client.socket))
                {
                    log("Client: ", index);
                    client.call();
                }
            }
            log(
                "\tTotal clients after messages handling: ",
                clients.length
            );

            // --------------------------
            // Handle new connections
            if (socketSet.isSet(listener))
            {
                Socket sn = null;
                scope (failure)
                {
                    stderr.writefln("Error accepting");

                    if (sn)
                    {
                        sn.close();
                    }
                }
                sn = listener.accept();
                assert(sn.isAlive);
                assert(listener.isAlive);

                if (clients.length < MAX_CONNECTIONS)
                {
                    clients ~= new Client(document, sn);
                    log("Total clients: ", clients.length);
                }
                else
                {
                    stderr.writefln(
                        "Too many connections! Rejected connection from ",
                        sn.remoteAddress().toString()
                    );
                    sn.close();
                    assert(!sn.isAlive);
                    assert(listener.isAlive);
                }

                log(
                    "\tTotal clients after accepting connections: ",
                    clients.length
                );
            }
        }

        // --------------------------
        // Process messages
        foreach (i; 0..7)
        {
            foreach (client; clients.filter!(x => x.state != Fiber.State.TERM))
            {
                client.call();
            }
        }

        // Clean up clients list
        bool cleanedUp = false;
        foreach (index, client; clients.filter!(x => x.state == Fiber.State.TERM).array)
        {
            log("Removing client ", index);
            client.socket.close();
            clients = clients.remove(index);
            log("Client removed: ", index);
            cleanedUp = true;
        }
        if (cleanedUp)
        {
            log(
                "Total clients after clean up: ",
                clients.length
            );
        }
    }

    return 0;
}
