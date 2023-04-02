module now.procedure;


import std.algorithm : canFind;

import now.exceptions;
import now.nodes;
import now.grammar;


class Procedure : BaseCommand
{
    SubProgram body;

    this(string name, Dict info)
    {
        super(name, info);

        auto bodyString = info["body"];
        auto parser = new NowParser(bodyString.toString());
        this.body = parser.consumeSubProgram();
    }

    override Context doRun(string name, Context context)
    {
        return context.process.run(this.body, context);
    }
}
