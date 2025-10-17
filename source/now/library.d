module now.library;


import std.json;
import std.process;

import now.json;
import now;


class Library : SystemCommand
{
    ProcessPipes pipes;
    std.process.Pid pid;
    string respawn;

    this(string name, Dict info, Document document)
    {
        super(name, info, document);

        info.on(
            "respawn",
            delegate (item) {
                this.respawn = item.toString;
            },
            delegate () {
                this.respawn = "on_error";
            }
        );
        log("Library ", name, ": respawn=", respawn);
    }

    void spawn()
    {
        /*
        command {
            - "ls"
            - $options
            - $path
        }
        We must evaluate that before running.
        */
        auto escopo = new Escopo(this.document, this.name);
        auto cmdline = getCommandLine(escopo);

        // set each variable on this Escopo as
        // a environment variable:
        // TODO: decide what type of env vars will be sent.
        string[string] env;

        // Evaluate workdir:
        string workdirStr = null;
        if (workdir !is null)
        {
            auto workdirOutput = workdir.evaluate(escopo);
            workdirStr = workdirOutput.front.toString();
        }

        // ---------------------
        // RUN THE PROCESS!
        this.pipes = pipeProcess(
            cmdline,
            Redirect.stdin | Redirect.stdout,
            env,
            Config(),
            workdirStr
        );
        this.pid = pipes.pid;
    }

    override ExitCode run(string name, Input input, Output output, bool keepScope=false)
    {
        /*
        > http_server start arg1 arg2 arg3
        */

        int counter = 0;
        while (true)
        {
            counter++;
            auto w = this.pid.tryWait();

            if (!w.terminated)
            {
                break;
            }
            else if (counter >= 10)
            {
                // do nothing
            }
            else if (this.respawn == "always")
            {
                this.spawn();
                continue;
            }
            else if (this.respawn == "on_error")
            {
                if (w.status != 0)
                {
                    this.spawn();
                    continue;
                }
            }

            // default
            throw new SystemProcessException(
                input.escopo,
                "Error while executing library " ~ this.toString(),
                w.status
            );
        }

        auto rpc_name = input.pop!string;
        JSONValue rpc_json = [ "op": "call" ];
        JSONValue json = [
            "rpc": rpc_json,
            "procedure": JSONValue(rpc_name),
            "args": ItemToJson(new List(input.popAll())),
            "kwargs": ItemToJson(new Dict(input.kwargs)),
        ];

        pipes.stdin.writeln(json.toString);
        pipes.stdin.flush();

        while (true)
        {
            auto response = pipes.stdout.readln();
            auto response_json = parseJSON(response);
            auto rpc = response_json["rpc"];
            auto op = rpc["op"].str;
            /*
               - return: returns a value
               - error: throws an error
               - call: calls a procedure
            */
            switch (op)
            {
                case "return":
                    output.push(JsonToItem(response_json["result"]));
                    return ExitCode.Success;
                case "error":
                    auto message = response_json["message"].str;
                    throw new NowException(
                        input.escopo,
                        message,
                    );
                case "call":
                    auto procedure = response_json["procedure"].str;
                    auto args = response_json["args"].array.map!(x => JsonToItem(x)).array;
                    auto kwargs = (cast(Dict)(JsonToItem(response_json["kwargs"]))).values;
                    auto user_data = response_json["user_data"];

                    auto callInput = Input(input.escopo, [], args, kwargs);
                    auto callOutput = new Output();
                    auto document = input.escopo.document;
                    auto callExitCode = document.runProcedure(procedure, callInput, callOutput);
                    // TODO: check callExitCode.

                    JSONValue return_rpc = [ "op": "return" ];

                    JSONValue return_result;
                    switch (callOutput.items.length)
                    {
                        case 0:
                            return_result = JsonNull;
                            break;
                        case 1:
                            return_result = ItemToJson(callOutput.pop());
                            break;
                        default:
                            return_result = ItemToJson(new List(callOutput.items));
                    }

                    JSONValue return_json = [
                        "rpc": return_rpc,
                        "result": return_result,
                        "user_data": user_data,
                    ];

                    pipes.stdin.writeln(return_json.toString);
                    pipes.stdin.flush();
                    break;

                default:
                    throw new NowException(
                        input.escopo,
                        "Invalid operation returned: " ~ op,
                    );
            }
        }
    }
}
