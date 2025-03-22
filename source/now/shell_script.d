module now.shell_script;


import now;


enum Consumes
{
    text,
    stdin,
    file,
}


class ShellScript : SystemCommand
{
    String body;
    string shellName;
    bool expandVariables = false;
    bool exposeCallerScope = false;
    bool exposeDocument = false;
    Consumes consumes;

    this(string shellName, Dict shellInfo, string name, Dict info, Document document)
    {
        log("ShellScript: ", shellName);

        this.shellName = shellName;

        // It's going to have no "parameters", since
        // we are passing the SHELL definition:
        super(name, shellInfo, document);

        log("ShellScript shellInfo: ", shellInfo);
        auto consumes = shellInfo.get("consumes", null);

        if (consumes is null)
        {
            this.consumes = Consumes.text;
        }
        else
        {
            this.consumes = consumes.toString.to!Consumes;
        }
        log("       this.consumes: ", this.consumes);

        // So we fix it now:
        log("       this.parameters: ", this.parameters);
        auto script_parameters = info.getOrCreate!Dict("parameters");
        log("       script_parameters -> ", script_parameters);

        foreach (key, value; script_parameters)
        {
            this.parameters[key] = value;
        }
        log("       this.parameters -> ", this.parameters);

        this.body = info.get!String("body", null);
        if (this.body is null)
        {
            throw new Exception(
                "ShellScript " ~ name ~ " must have a body"
            );
        }
        this.expandVariables = info.get!bool("expand_variables", false);
        this.exposeDocument = info.get!bool("expose_document", false);
        this.exposeCallerScope = info.get!bool("expose_caller_scope", false);

        // Local event handlers:
        this.loadEventHandlers(info);
    }
    override ExitCode run(string name, Input input, Output output, bool keepScope=false)
    {
        return super.run(name, input, output, (keepScope || exposeCallerScope));
    }
    override ExitCode preRun(string name, Input input, Output output)
    {
        /*
        Important: THIS escopo is NOT the caller's escopo!
        It's the script one, just like the new scope inside
        a Procedure!
        */
        auto escopo = input.escopo;

        if (expandVariables)
        {
            auto parser = new NowParser(this.body.toString());
            auto substString = parser.consumeString(cast(char)null);
            this.body = cast(String)(substString.evaluate(escopo).front);
        }

        if (consumes == Consumes.text)
        {
            escopo["script_body"] = this.body;
        }
        escopo["script_name"] = new String(this.name);
        escopo["script_call_name"] = new String(name);
        escopo["shell_name"] = new String(this.shellName);

        if (exposeDocument)
        {
            foreach (key, value; escopo.document)
            {
                escopo[key] = value;
            }
        }
        log("    ShellScript escopo.parent: ", escopo.parent);
        if (exposeCallerScope && escopo.parent !is null)
        {
            foreach (key, value; input.escopo.parent)
            {
                escopo[key] = value;
            }
        }

        return ExitCode.Success;
    }
    override ExitCode doRun(string name, Input input, Output output)
    {
        if (consumes == Consumes.stdin)
        {
            input.inputs = (cast(Item[])[this.body]) ~ input.inputs;
            log("ShellScript inputs:", input.inputs);
        }
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
