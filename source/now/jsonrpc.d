module now.jsonrpc;

import std.json;


const INVALID_REQUEST = -32600;
const PARSE_ERROR = -32700;
const METHOD_NOT_FOUND = -32601;


string jsonrpcError(long code, string message, JSONValue request_id = null)
{
    JSONValue errorObject = ["code": code];
    errorObject["message"] = message;

    JSONValue errorResponse = ["id": request_id];
    errorResponse.object["jsonrpc"] = "2.0";
    errorResponse.object["error"] = errorObject;

    return errorResponse.toString;
}

string jsonrpcResponse(JSONValue request_id, JSONValue result)
{
    JSONValue response = ["id": request_id];
    response.object["jsonrpc"] = "2.0";
    response.object["result"] = result;

    return response.toString;
}
