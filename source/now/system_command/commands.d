module now.system_command.commands;

import now.nodes;
import now.system_command;


static this()
{
    systemProcessCommands["get"] = function (string path, Context context)
    {
        SystemProcess target = context.pop!SystemProcess();

        if (context.size == 0) return context;
        string argument = context.pop!string();

        switch (argument)
        {
            case "is_running":
                context.push(target.isRunning);
                break;
            case "cmdline":
                foreach (item; target.cmdline)
                {
                    context.push(item);
                }
                break;
            case "pid":
                context.push(target.pid.processID());
                break;
            case "return_code":
                target.wait();
                context.push(target.returnCode);
                break;
            default:
                break;
        }

        context.exitCode = ExitCode.Success;
        return context;
    };
    systemProcessCommands["wait"] = function (string path, Context context)
    {
        auto p = context.pop!SystemProcess();
        p.wait();
        return context.push(p.returnCode);
    };
    systemProcessCommands["success"] = function (string path, Context context)
    {
        auto p = context.pop!SystemProcess();
        p.wait();
        return context.push(p.returnCode == 0);
    };
    systemProcessCommands["check"] = function (string path, Context context)
    {
        auto p = context.pop!SystemProcess();
        p.wait();
        if (p.returnCode != 0)
        {
            auto msg = "Error while executing " ~ p.toString();
            return context.error(msg, p.returnCode, "", p);
        }
        return context;
    };
    systemProcessCommands["kill"] = function (string path, Context context)
    {
        return context.error(
            "Not implemented yet",
            ErrorCode.NotImplemented,
            ""
        );
    };
}
