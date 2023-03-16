module now.nodes.system_commands.commands;

import now.nodes;
import now.nodes.system_commands;


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
            case "error":
                context.push(new SystemProcessError(target));
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
    systemProcessCommands["kill"] = function (string path, Context context)
    {
        return context.error(
            "Not implemented yet",
            ErrorCode.NotImplemented,
            ""
        );
    };
}
