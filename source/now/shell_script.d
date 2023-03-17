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
}
