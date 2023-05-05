module now.system_command.methods;


import now;
import now.system_command;


static this()
{
    systemProcessMethods["get"] = function (Item target, string path, Input input, Output output)
    {
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
                output.items ~= new Boolean(process.isRunning);
                break;
            case "cmdline":
                output.items ~= process.cmdline.map!(x => new String(x)).array;
                break;
            case "pid":
                output.items ~= new Integer(process.pid.processID());
                break;
            case "return_code":
                process.wait();
                output.items ~= new Integer(process.returnCode);
                break;
            default:
                break;
        }

        return ExitCode.Success;
    };
    systemProcessMethods["wait"] = function (Item target, string path, Input input, Output output)
    {
        auto process = cast(SystemProcess)target;

        process.wait();
        output.items ~= new Integer(process.returnCode);
        return ExitCode.Success;
    };
    systemProcessMethods["success"] = function (Item target, string path, Input input, Output output)
    {
        auto process = cast(SystemProcess)target;

        process.wait();
        output.items ~= new Boolean(process.returnCode == 0);
        return ExitCode.Success;
    };
    systemProcessMethods["check"] = function (Item target, string path, Input input, Output output)
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
        return ExitCode.Success;
    };
    systemProcessMethods["kill"] = function (Item target, string path, Input input, Output output)
    {
        auto process = cast(SystemProcess)target;

        throw new NotImplementedException(
            input.escopo,
            "Not implemented yet"
        );
    };
}
