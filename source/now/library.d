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

        auto rpcName = input.pop!string;
        // ["call" "${rpc_name}", [args, ...], {kw: args, ...}]
        JSONValue json = [
            JSONValue("call"),
            JSONValue(rpcName),
            ItemToJson(new List(input.popAll())),
            ItemToJson(new Dict(input.kwargs)),
        ];

        pipes.stdin.writeln(json.toString);
        pipes.stdin.flush();

        ExitCode exitCode = ExitCode.Success;
        // Return is a special-case flag here.
        do
        {
            exitCode = processResponse(input, output);
            log("exitCode=", exitCode);
        } while (exitCode == ExitCode.Return);

        log(" Library.run quitting...");
        return exitCode;
    }

    ExitCode processResponse(Input input, Output output)
    {
        log("processResponse...");
        auto response = pipes.stdout.readln();
        auto response_json = parseJSON(response);
        log("response_json=", response_json);
        // ["${op}", "${rpc_name}", [args, ...], {kw: args, ...}, {user: data, ...}]
        auto op = response_json[0].str;
        auto rpcName = response_json[1].str;
        auto args = response_json[2];
        auto kwargs = response_json[3];
        log(" op=", op, " rpcName=", rpcName, " args=", args, " kwargs=", kwargs);
        /*
           - return: returns a value
           - error: throws an error
           - call: calls a procedure
        */
        switch (op)
        {
            case "return":
                auto returnedList = cast(List)(JsonToItem(args));
                output.push(returnedList.items);
                return ExitCode.Success;
            case "event":
            case "error":
                auto message = args[0].str;
                log(" args[0]=", args[0]);
                log(" error message=", message);
                auto ex = new NowException(
                    input.escopo,
                    message,
                );
                ex.classe = message;
                throw ex;
            case "call":
                auto itemArgs = args.array.map!(x => JsonToItem(x)).array;
                auto itemKwargs = (cast(Dict)(JsonToItem(kwargs))).values;

                log(" library call! ", itemArgs, " ", itemKwargs);

                auto callInput = Input(input.escopo, [], itemArgs, itemKwargs);
                auto callOutput = new Output();
                auto document = input.escopo.document;
                auto callExitCode = document.runProcedure(rpcName, callInput, callOutput);
                // TODO: check callExitCode.
                log(" library call exit code=", callExitCode);
                log(" output: ", callOutput.items);

                JSONValue return_result = ItemToJson(new List(callOutput.items));
                auto userData = response_json[4];

                auto return_json = JSONValue([
                    JSONValue("return"),
                    JSONValue(rpcName),
                    return_result,
                    JSONValue.emptyObject,
                    userData,
                ]);
                log(" return_json=", return_json);

                pipes.stdin.writeln(return_json.toString);
                pipes.stdin.flush();
                // Return is a special-case flag here.
                return ExitCode.Return;

            default:
                throw new NowException(
                    input.escopo,
                    "Invalid operation returned: " ~ op,
                );
        }
        return ExitCode.Success;
    }
}
