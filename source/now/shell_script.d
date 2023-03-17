module now.shell_script;


import now.nodes;


class ShellScript : SystemCommand
{
    String body;
    string shellName;

    this(string shellName, Dict shellInfo, string name, Dict info)
    {
        this.shellName = shellName;

        // It's going to have no "parameters", since
        // we are passing the SHELL definition:
        debug {
            stderr.writeln("ShellScript ", name, " shellInfo:", shellInfo);
        }
        super(name, shellInfo);
        // So we fix it now:
        this.parameters = info.getOrCreate!Dict("parameters");

        this.body = info.get!String(
            "body",
            delegate (Dict d) {
                throw new Exception(
                    "ShellScript " ~ name ~ " must have a body"
                );
                return cast(String)null;
            }
        );
    }
    override Context preRun(string name, Context context)
    {
        auto escopo = context.escopo;
        escopo["script_body"] = this.body;
        escopo["script_name"] = new String(this.name);
        escopo["script_call_name"] = new String(name);
        escopo["shell_name"] = new String(this.shellName);
        return context;
    }
    override Context doRun(string name, Context context)
    {
        context = super.doRun(name, context);
        /*
        What the SystemCommand do is to push
        a new SystemProcess, so we can peek the
        stack and set that as a variable so that
        event handlers can access the process (to wait
        for it to finish, for instance).
        */
        if (context.exitCode != ExitCode.Failure)
        {
            auto process = context.peek();
            debug {
                stderr.writeln(" process? ", process, " / ", process.type);
            }
            if (process.type == ObjectType.SystemProcess)
            {
                context.escopo["process"] = process;
            }
        }
        return context;
    }
}
