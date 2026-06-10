module now.mcp_server;

import now.nodes;

import now.cli;
import now.escopo;
import now.json;
import now.jsonrpc;
import now.procedure;

import core.exception : RangeError;
import std.json;
import std.regex;


Dict[][string] lists;
Procedure[string] entrypoints;
Procedure initializeProcedure;


template print(T)
{
    void print(T msg...)
    {
        log("print> ", msg);
        stdout.writeln(msg);
        stdout.flush();
    }
}

int main(string[] args)
{
    return cliMain(args, &mcpServer);
}

int mcpServer(Document document, string[] documentArgs)
{
    log("+ mcpServer");

    auto uriRegex = regex(r"\{(?P<atom>[^/]+)\}");

    // Turn MCP tools, resource templates, etc into Procedures:
    auto mcp = document.data.get!Dict("mcp");
    auto tools = mcp.getOrCreate!Dict("tools");
    auto resources = mcp.getOrCreate!Dict("resources");
    auto prompts = mcp.getOrCreate!Dict("prompts");

    auto initializeProcedureInfo = mcp.get("initialize", null);
    if (initializeProcedureInfo !is null)
    {
        initializeProcedure = new Procedure("initialize", cast(Dict)initializeProcedureInfo);
    }

    auto dictMap = [
        "tools": tools,
        "resources": resources,
        "prompts": prompts
    ];

    // TODO: do the same for HTTP:
    // [http/index/get]
    foreach (thing, list; dictMap)
    {
        foreach (name, infoItem; list.values)
        {
            log("-- mcp tool: ", name);
            auto info = cast(Dict)infoItem;

            switch (thing)
            {
                case "resources":
                    string uri = info.values["uri"].toString;
                    string reUri = uri.replaceAll(uriRegex, "(\?P<$1>[^/]+)");
                    log("reUri=", reUri);
                    entrypoints[reUri] = new Procedure(name, info);
                    break;
                default:
                    entrypoints[name] = new Procedure(name, info);
            }

            auto exposedDict = new Dict(info.values);
            exposedDict.remove("body");
            exposedDict.remove("depends_on");
            // TODO: adjust "parameters"
            exposedDict["name"] = new String(name);

            if (thing == "tools")
            {
                exposedDict.remove("parameters");
                auto required = new List([]);
                exposedDict["inputSchema"] = new Dict([
                    "type": new String("object"),
                    "properties": info["parameters"],
                    "required": required
                ]);

                foreach (key, value; cast(Dict)(info["parameters"]))
                {
                    auto parameter = cast(Dict)value;
                    if (("default" in parameter.values) is null)
                    {
                        required.items ~= new String(key);
                    }
                }
            }
            else
            {
                foreach (key, value; cast(Dict)(info["parameters"]))
                {
                    auto parameter = cast(Dict)value;
                    if (("default" in parameter.values) is null)
                    {
                        parameter["required"] = new Boolean(true);
                    }
                }
            }

            lists[thing] ~= exposedDict;
        }
    }

    foreach (line; stdin.byLine)
    {
        processRequest(line.to!string, document);
    }
    return 0;
}

void processRequest(string request, Document document)
{
    ExitCode exitCode = ExitCode.Success;
    JSONValue request_json;

    try
    {
        request_json = parseJSON(request);
    }
    catch (Exception ex)
    {
        print(jsonrpcError(PARSE_ERROR, "Parse error"));
        return;
    }

    log("request_json=", request_json);

    string jsonrpc;
    JSONValue request_id;
    string name;
    bool isNotification = false;

    try
    {
        request_id = request_json["id"];
    }
    catch (JSONException)
    {
        request_id = null;
        isNotification = true;
    }

    try
    {
        jsonrpc = request_json["jsonrpc"].str;
        name = request_json["method"].str;
    }
    catch (Exception ex)
    {
        log(ex);
        print(jsonrpcError(INVALID_REQUEST, "Invalid Request", request_id));
        return;
    }

    if (jsonrpc != "2.0")
    {
        log("jsonrpc=", jsonrpc);
        print(jsonrpcError(INVALID_REQUEST, "Invalid Request", request_id));
        return;
    }

    Dict params;
    if (JSONValue* paramsRef = "params" in request_json)
    {
        params = cast(Dict)(JsonToItem(*paramsRef));
    }

    switch (name) {
        case "initialize":
            initialize(document, request_id);
            break;
        case "prompts/list":
            showList("prompts", request_id);
            break;
        case "prompts/get":
            getPrompt(document, params, request_id);
            break;
        // case "completion/complete":
        case "tools/list":
            showList("tools", request_id);
            break;
        case "tools/call":
            callTool(document, params, request_id);
            break;
        // case "tasks/list":
        // case "tasks/get":
        // case "tasks/result":
        // case "tasks/cancel":
        case "resources/list":
             showList("resources", request_id);
             break;
        case "resources/read":
             readResource(document, params, request_id);
             break;
        case "resources/templates/list":
            showList("resources", request_id);
            break;
        // case "resources/subscribe":
        default:
            if (isNotification)
            {
                log("notification ignored.");
            }
            else
            {
                print(jsonrpcError(METHOD_NOT_FOUND, "Method not found", request_id));
            }
    }
}

ExitCode initialize(Document document, JSONValue request_id)
{
    Dict result = new Dict([
        "protocolVersion": "2025-11-25",
        "instructions": "",
    ]);
    result["capabilities"] = new Dict([
        "logging": new Dict(),
        "prompts": new Dict([
            "listChanged": new Boolean(false)
        ]),
        "resources": new Dict([
            "subscribe": new Boolean(false),
            "listChanged": new Boolean(false),
        ]),
        "tools": new Dict([
            "listChanged": new Boolean(false),
        ]),
        /*
        "tasks": new Dict([
            "list": new Dict(),
            "cancel": new Dict(),
            "requests": new Dict([
                "tools": new Dict([
                    "call": new Dict()
                ])
            ]),
        ]),
        */
    ]);
    result["serverInfo"] = new Dict([
        "name": document.title,
        "description": document.description,
        "version": "0.0.1",
    ]);

    // TODO: call `mcp/initialize` procedure so the user can
    // alter the response dict.
    if (initializeProcedure !is null)
    {
        auto initOutput = new Output();
        auto escopo = new Escopo(document, "initialize");
        escopo["result"] = result;
        Args args;
        KwArgs kwargs;
        auto initInput = Input(
            escopo,
            [],
            args,
            kwargs
        );
        initializeProcedure.run("initialize", initInput, initOutput, true);
        // XXX: should we analyze the exitCode?
        // XXX: should we do something with the output???
    }

    print(jsonrpcResponse(request_id, ItemToJson(result)));
    return ExitCode.Success;
}

void showList(string key, JSONValue request_id)
{
    log(lists[key]);

    print(jsonrpcResponse(
        request_id,
        JSONValue([key: lists[key].map!(x => ItemToJson(x)).array])
    ));
}


Item call(Document document, string name, Dict params, JSONValue request_id)
{
    log("call: ", name, " params=", params, " [", request_id, "]");

    Args args;
    KwArgs kwargs = (params.getOrCreate!Dict("arguments")).values;

    auto escopo = new Escopo(document, name);

    auto newInput = Input(
        escopo,
        [],
        args,
        kwargs
    );
    auto newOutput = new Output();

    log("entrypoints=",entrypoints);
    ExitCode exitCode;
    try
    {
        exitCode = entrypoints[name].run(name, newInput, newOutput, true);
    }
    catch (ProcedureNotFoundException ex)
    {
        log(ex);
        print(jsonrpcError(METHOD_NOT_FOUND, "Method not found", request_id));
        return null;
    }
    catch (InvalidArgumentsException ex)
    {
        log(ex);
        print(jsonrpcError(INVALID_REQUEST, "Invalid Request", request_id));
        return null;
    }
    catch (NowException ex)
    {
        log(ex);
        print(jsonrpcError(ex.code, ex.message.to!string, request_id));
        return null;
    }

    log("output:", newOutput.items);
    if (newOutput.items.length == 1)
    {
        return newOutput.items[0];
    }
    else
    {
        return new List(newOutput.items);
    }
}

void callTool(Document document, Dict params, JSONValue request_id)
{
    log("callTool");
    JSONValue response = ["id": request_id];
    response.object["jsonrpc"] = "2.0";

    auto value = call(document, params["name"].toString, params, request_id);
    if (value is null)
    {
        return;
    }
    log("value.type=", value.type);
    log("value=", value);

    JSONValue result = ["isError": false];
    JSONValue content = ["type": "text"];

    switch (value.type)
    {
        case ObjectType.String:
            content.object["text"] = value.toString;
            break;
        default:
            break;
    }

    // XXX: but how can the user return a list of multiple
    // things, like text + image?
    result.object["content"] = [content];
    response.object["result"] = result;

    print(response.toString);
}

void readResource(Document document, Dict params, JSONValue request_id)
{
    log("readResource");
    JSONValue response = ["id": request_id];
    response.object["jsonrpc"] = "2.0";

    string uri = params["uri"].toString;

    auto entrypointRef = (uri in entrypoints);
    if (entrypointRef is null)
    {
        bool found = false;
        foreach (candidateUri, entrypoint; entrypoints)
        {
            log(" -- trying ", candidateUri, " for ", uri);

            auto uriRegex = regex(candidateUri);
            auto groups = uri.matchFirst(uriRegex);
            if (groups)
            {
                log(" --- groups=", groups);

                auto arguments = params.getOrCreate!Dict("arguments");
                foreach(key; uriRegex.namedCaptures)
                {
                    log(" ---- key=", key, "=", groups[key]);
                    arguments[key] = new String(groups[key]);
                }
                uri = candidateUri;
                found = true;
                log(" ----- params=", params);
                break;
            }
        }
        if (!found)
        {
            print(jsonrpcError(METHOD_NOT_FOUND, "Method not found", request_id));
            return;
        }
    }

    auto value = call(document, uri, params, request_id);
    if (value is null)
    {
        return;
    }
    log("value.type=", value.type);
    log("value=", value);

    auto definition = entrypoints[uri].info;

    JSONValue contents = [
        "uri": definition["uri"].toString,
        "mimeType": definition["mime_type"].toString
    ];
    JSONValue result = [
        "contents": [contents],
    ];

    switch (value.type)
    {
        case ObjectType.String:
            contents.object["text"] = value.toString;
            break;
        default:
            break;
    }
    response.object["result"] = result;

    print(response.toString);
}

void getPrompt(Document document, Dict params, JSONValue request_id)
{
    log("getPrompt");
    JSONValue response = ["id": request_id];
    response.object["jsonrpc"] = "2.0";

    auto value = call(document, params["name"].toString, params, request_id);
    if (value is null)
    {
        return;
    }
    log("value.type=", value.type);
    log("value=", value);
    log("value.properties=", value.properties);

    string role = "user";

    if (Item* roleRef = ("role" in value.properties))
    {
        role = (*roleRef).toString;
    }

    // TODO: improve this:
    JSONValue result = ["description": "prompt"];
    JSONValue messages;
    messages.array = [JSONValue([
        "role": JSONValue(role),
        "content": JSONValue([
            "type": "text",
            "text": value.toString
        ])
    ])];

    result.object["messages"] = messages;
    response.object["result"] = result;

    print(response.toString);
}
