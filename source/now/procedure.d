module now.procedure;


import now;


class Procedure : BaseCommand
{
    SubProgram body;
    bool useParentScope = false;

    this(string name, Dict info)
    {
        super(name, info);

        auto bodyString = info["body"];
        // XXX: should we start parsing lazily?
        auto parser = new NowParser(bodyString.toString());
        parser.line = bodyString.documentLineNumber;
        this.body = parser.consumeSubProgram();

        info.on(
            "use_parent_scope",
            delegate (Item item) {
                this.useParentScope = (cast(Boolean)item).toBool;
            },
            delegate () {
            }
        );
    }
    override ExitCode run(string name, Input input, Output output, bool keepScope=false)
    {
        return super.run(name, input, output, (keepScope || this.useParentScope));
    }

    override ExitCode doRun(string name, Input input, Output output)
    {
        input.escopo.rootCommand = this;
        return this.body.run(input.escopo, output);
    }
}
