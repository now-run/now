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
    ulong request_id;

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

        auto rpcName = input.pop!string;

        auto json = JSONValue([
            "jsonrpc": "2.0",
            "method": rpcName
        ]);
        json["id"] = request_id++;
        json["params"] = ItemToJson(new List(input.popAll()));
        // TODO: allow keyword arguments!
        // ItemToJson(new Dict(input.kwargs)),

        pipes.stdin.writeln(json.toString);
        pipes.stdin.flush();

        log("processResponse...");
        auto response = pipes.stdout.readln();
        log("response=", response);

        auto exitCode = processResponse(response, input, output);
        log(" Library.run quitting; exitCode=", exitCode);
        return exitCode;
    }

    ExitCode processResponse(string response, Input input, Output output)
    {
        // TODO: handle invalid JSON
        auto response_json = parseJSON(response);
        log("response_json=", response_json);

        auto jsonrpc = response_json["jsonrpc"].str;
        auto response_id = response_json["id"];

        Item result;
        if (JSONValue* resultRef = "result" in response_json)
        {
            result = JsonToItem(*resultRef);
        }
        Item error;
        if (JSONValue* errorRef = "error" in response_json)
        {
            error = JsonToItem(*errorRef);
        }

        if (result !is null)
        {
            output.push(result);
            return ExitCode.Success;
        }
        if (error !is null)
        {
            auto errorMsg = (cast(String)error).toString;
            auto ex = new NowException(
                input.escopo,
                errorMsg
            );
            ex.classe = errorMsg;
            throw ex;
        }

        // XXX: is this line reachable???
        return ExitCode.Success;
        throw new NowException(
            input.escopo,
            "No result or error were returned in json-rpc response!",
            new String(response),
            -1
        );
    }
}
