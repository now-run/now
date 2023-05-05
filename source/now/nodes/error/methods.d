module now.nodes.error.methods;


import now;


static this()
{
    errorMethods["get"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > print [get $error code]
        404
        > print [get $error message]
        not found
        */
        // TODO: turn it into real methods, like
        // > $error : message
        auto target = cast(Erro)object;
        auto arg = input.popAll.map!(x => x.toString).join(" ");

        switch(arg)
        {
            case "code":
                output.push(target.code);
                return ExitCode.Success;
            case "message":
                output.push(target.message);
                return ExitCode.Success;
            case "class":
                output.push(target.classe);
                return ExitCode.Success;
            case "subject":
                if (target.subject is null)
                {
                    throw new UndefinedException(
                        input.escopo,
                        "No subject defined for this error",
                        -1,
                        target
                    );
                }
                else
                {
                    output.push(target.subject);
                    return ExitCode.Success;
                }
            default:
                auto msg = "Invalid argument to get from Error";
                throw new InvalidArgumentsException(
                    input.escopo,
                    msg,
                    -1,
                    target
                );
        }
    };
    errorMethods["."] = errorMethods["get"];

    errorMethods["return"] = function (Item object, string path, Input input, Output output)
    {
        // Do not pop the error: we would stack it back, anyway...
        // auto target = input.pop!Erro();
        throw (cast(Erro)object).exception;
    };
}
