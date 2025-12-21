module now.system_command.methods;

import core.sys.posix.signal : SIGKILL;
import std.process : kill;

import now;
import now.system_command;


static this()
{
    systemProcessMethods["get"] = function(Item target, string path, Input input, Output output)
    {
        // TODO: get rid of this, probably.

        auto process = cast(SystemProcess)target;

        if (input.args.length == 0)
        {
            throw new SyntaxErrorException(
                input.escopo,
                "`get` must receive a key as argument"
            );
        }
        string argument = input.pop!string();

        switch (argument)
        {
            case "is_running":
                output.push(process.isRunning);
                break;
            case "cmdline":
                output.items ~= process.cmdline.map!(x => new String(x)).array;
                break;
            case "pid":
                output.push(process.pid.processID());
                break;
            case "return_code":
                process.wait();
                output.push(process.returnCode);
                break;
            default:
                break;
        }

        return ExitCode.Success;
    };
    systemProcessMethods["feed"] = function(Item target, string path, Input input, Output output)
    {
        // TODO: get rid of this, probably.

        auto process = cast(SystemProcess)target;

        foreach (item; input.popAll)
        {
            process.pipes.stdin.writeln(item.toString);
        }
        process.pipes.stdin.flush();

        output.push(process);
        return ExitCode.Success;
    };

    systemProcessMethods["wait"] = function(Item target, string path, Input input, Output output)
    {
        auto process = cast(SystemProcess)target;

        log("Process inputStream is ", process.inputStream);
        if  (process.inputStream !is null)
        {
            auto nextOutput = new Output;
            while (process.inputStream !is null)
            {
                log("Process is running ", process.inputStream);
                process.next(input.escopo, nextOutput);
            }
        }

        log("Waiting for ", process);
        process.wait();
        output.push(process.returnCode);
        return ExitCode.Success;
    };
    systemProcessMethods["success"] = function(Item target, string path, Input input, Output output)
    {
        auto process = cast(SystemProcess)target;

        process.wait();
        output.push(process.returnCode == 0);
        return ExitCode.Success;
    };
    systemProcessMethods["check"] = function(Item target, string path, Input input, Output output)
    {
        auto process = cast(SystemProcess)target;

        process.wait();
        if (process.returnCode != 0)
        {
            throw new SystemProcessException(
                input.escopo,
                "Error while executing " ~ process.toString,
                process.returnCode,
                process
            );
        }
        output.push(process);
        return ExitCode.Success;
    };
    systemProcessMethods["output"] = function(Item target, string path, Input input, Output output)
    {
        auto process = cast(SystemProcess)target;
        output.push(process.getOutput(input.escopo));
        return ExitCode.Success;
    };
    systemProcessMethods["kill"] = function(Item target, string path, Input input, Output output)
    {
        auto process = cast(SystemProcess)target;
        process.pid.kill(SIGKILL);
        process.wait;
        process.isRunning; //  mark _isRunning as false!
        output.push(process.returnCode);
        return ExitCode.Success;
    };
}
