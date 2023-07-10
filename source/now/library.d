module now.library;


import std.json;
import std.process;

import now.json;
import now;


class Library : SystemCommand
{
    ProcessPipes pipes;
    std.process.Pid pid;

    this(string name, Dict info, Document document)
    {
        super(name, info, document);
    }

    void spawn(Document document)
    {
        /*
        command {
            - "ls"
            - $options
            - $path
        }
        We must evaluate that before running.
        */
        auto escopo = new Escopo(document, this.name);
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
        auto rpc_name = input.pop!string;
        JSONValue rpc_json = [ "name": rpc_name, "op": "call" ];
        JSONValue json = [
            "rpc": rpc_json,
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
            // TODO: extend handling of various operations.
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
                    auto result = response_json["result"];
                    throw new NowException(
                        input.escopo,
                        result["message"].str,
                    );
                case "call":
                    throw new NotImplementedException(
                        input.escopo,
                        "Operation `call` not implemented, yet."
                    );
                default:
                    throw new NowException(
                        input.escopo,
                        "Invalid operation returned: " ~ op,
                    );
            }
        }
    }
}
