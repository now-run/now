module now.nodes.error.commands;


import now.nodes;


static this()
{
    errorCommands["get"] = function (string path, Context context)
    {
        /*
        > print [get $error code]
        404
        > print [get $error message]
        not found
        */
        auto target = context.pop!Erro();
        auto args = context.items!string;
        auto arg = args.join(" ");

        switch(arg)
        {
            case "code":
                return context.push(target.code);
            case "message":
                return context.push(target.message);
            case "class":
                return context.push(target.classe);
            case "subject":
                if (target.subject is null)
                {
                    return context.error(
                        "No subject defined for this error",
                        ErrorCode.Undefined,
                        ""
                    );
                }
                else
                {
                    return context.push(target.subject);
                }
            default:
                auto msg = "Invalid argument to get from Error";
                return context.error(msg, ErrorCode.InvalidArgument, "");
        }
    };
    errorCommands["."] = errorCommands["get"];

    errorCommands["return"] = function (string path, Context context)
    {
        // Do not pop the error: we would stack it back, anyway...
        // auto target = context.pop!Erro();
        context.exitCode = ExitCode.Failure;
        return context;
    };
}
