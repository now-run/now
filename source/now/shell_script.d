module now.shell_script;


import now;


class ShellScript : SystemCommand
{
    String body;
    string shellName;
    bool expandVariables = false;

    this(string shellName, Dict shellInfo, string name, Dict info, Document document)
    {
        this.shellName = shellName;

        // It's going to have no "parameters", since
        // we are passing the SHELL definition:
        super(name, shellInfo, document);

        // So we fix it now:
        this.parameters = info.getOrCreate!Dict("parameters");

        this.body = info.get!String("body", null);
        if (this.body is null)
        {
            throw new Exception(
                "ShellScript " ~ name ~ " must have a body"
            );
        }
        this.expandVariables = info.get!bool("expand_variables", false);

        // Local event handlers:
        this.loadEventHandlers(info);
    }
    override ExitCode preRun(string name, Input input, Output output)
    {
        auto escopo = input.escopo;

        String body;
        if (expandVariables)
        {
            auto parser = new NowParser(this.body.toString());
            auto substString = parser.consumeString(cast(char)null);
            body = cast(String)(substString.evaluate(escopo).front);
        }
        else
        {
            body = this.body;
        }

        escopo["script_body"] = body;
        escopo["script_name"] = new String(this.name);
        escopo["script_call_name"] = new String(name);
        escopo["shell_name"] = new String(this.shellName);

        return ExitCode.Success;
    }
    override ExitCode doRun(string name, Input input, Output output)
    {
        auto exitCode = super.doRun(name, input, output);
        /*
        What the SystemCommand do is to push
        a new SystemProcess, so we can peek the
        stack and set that as a variable so that
        event handlers can access the process (to wait
        for it to finish, for instance).
        */
        auto process = output.items.front;
        if (process.type == ObjectType.SystemProcess)
        {
            input.escopo["process"] = process;
        }
        return exitCode;
    }
}
