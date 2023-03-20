module now.shell_script;


import now.nodes;
import now.grammar;


class ShellScript : SystemCommand
{
    String body;
    string shellName;
    bool expandVariables = false;

    this(string shellName, Dict shellInfo, string name, Dict info)
    {
        this.shellName = shellName;

        // It's going to have no "parameters", since
        // we are passing the SHELL definition:
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
        this.expandVariables = info.get!BooleanAtom(
            "expand_variables",
            delegate (Dict d) {
                auto v = new BooleanAtom(false);
                d["expand_variables"] = v;
                return v;
            }
        ).toBool();

    }
    override Context preRun(string name, Context context)
    {
        auto escopo = context.escopo;

        String body;
        if (expandVariables)
        {
            // XXX: will it work properly???
            auto parser = new Parser(this.body.toString());
            auto substString = parser.consumeString(cast(char)null);
            context = substString.evaluate(context);
            body = context.pop!String();
        }
        else
        {
            body = this.body;
        }

        escopo["script_body"] = body;
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
            if (process.type == ObjectType.SystemProcess)
            {
                context.escopo["process"] = process;
            }
        }
        return context;
    }
}
