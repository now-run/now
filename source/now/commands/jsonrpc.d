module now.commands.jsonrpc;

import std.json;

import now;
import now.commands;
import now.json;
import now.jsonrpc;

ulong requestId = 0;

void loadJsonrpcCommands(CommandsMap commands)
{
    commands["jsonrpc.call"] = function(string path, Input input, Output output)
    {
        string method = input.pop!string;

        JSONValue args = ItemToJson(new List(input.popAll));


        JSONValue response = ["jsonrpc": "2.0", "method": method];
        response.object["id"] = ++requestId;

        response.object["params"] = args;
        if (input.kwargs)
        {
            response.object["params"] = ItemToJson(new Dict(input.kwargs));
        }

        output.push(response.toString);

        return ExitCode.Success;
    };
    commands["jsonrpc.process"] = function(string path, Input input, Output output)
    {
        /*
        > o "{json-rpc request for method x}" | jsonrpc:process
        calls x
        returns a json-rpc response string
        */

        string prefix = "rpc:";
        if (auto prefixPtr = ("prefix" in input.kwargs))
        {
            prefix = (*prefixPtr).toString;
        }

        ExitCode exitCode = ExitCode.Success;

        foreach (item; input.popAll)
        {
            auto request = item.toString;
            JSONValue request_json;

            try
            {
                request_json = parseJSON(request);
            }
            catch (Exception ex)
            {
                JSONValue errorObject = ["code": -32700];
                errorObject["message"] = "Parse error";

                JSONValue errorResponse = ["id": null];
                errorResponse.object["jsonrpc"] = "2.0";
                errorResponse.object["error"] = errorObject;

                output.push(errorResponse.toString);
                continue;
            }

            log("request_json=", request_json);

            auto jsonrpc = request_json["jsonrpc"].str;
            if (jsonrpc != "2.0")
            {
                JSONValue errorObject = ["code": -32600];
                errorObject["message"] = "Invalid Request";

                JSONValue errorResponse = ["id": null];
                errorResponse.object["jsonrpc"] = "2.0";
                errorResponse.object["error"] = errorObject;

                output.push(errorResponse.toString);
                continue;
            }

            auto request_id = request_json["id"];
            auto original_name = request_json["method"].str;
            string name = prefix ~ original_name;

            Args args;
            KwArgs kwargs;

            if (JSONValue* paramsRef = "params" in request_json)
            {
                auto params = JsonToItem(*paramsRef);
                if (params.type == ObjectType.Dict)
                {
                    kwargs = (cast(Dict)params).values;
                }
                else
                {
                    args = (cast(List)params).items;
                }
            }

            auto newInput = Input(
                input.escopo,
                [],
                args,
                kwargs
            );
            auto newOutput = new Output();

            try
            {
                exitCode = input.escopo.document.runProcedure(
                    name, newInput, newOutput
                );
            }
            catch (ProcedureNotFoundException ex)
            {
                JSONValue errorObject = ["code": -32601];
                errorObject["message"] = "Method not found";

                JSONValue errorResponse = ["id": request_id];
                errorResponse.object["jsonrpc"] = "2.0";
                errorResponse.object["error"] = errorObject;

                output.push(errorResponse.toString);
                continue;
            }
            catch (InvalidArgumentsException ex)
            {
                JSONValue errorObject = ["code": -32600];
                errorObject["message"] = "Invalid Request";

                JSONValue errorResponse = ["id": request_id];
                errorResponse.object["jsonrpc"] = "2.0";
                errorResponse.object["error"] = errorObject;

                output.push(errorResponse.toString);
                continue;
            }
            catch (NowException ex)
            {
                JSONValue errorObject = ["code": ex.code];
                errorObject["message"] = ex.message;

                JSONValue errorResponse = ["id": request_id];
                errorResponse.object["jsonrpc"] = "2.0";
                errorResponse.object["error"] = errorObject;

                output.push(errorResponse.toString);
                continue;
            }

            // Return whatever is in newOutput:
            JSONValue response = ["id": request_id];
            response.object["jsonrpc"] = "2.0";

            if (newOutput.items.length == 1)
            {
                response.object["result"] = ItemToJson(newOutput.items[0]);
            }
            else
            {
                response.object["result"] = ItemToJson(new List(newOutput.items));
            }

            output.push(response.toString);
        }

        return exitCode;
    };
}
