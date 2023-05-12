module now.procedure;


import std.algorithm : canFind;

import now;
import now.exceptions;


class Procedure : BaseCommand
{
    SubProgram body;

    this(string name, Dict info)
    {
        super(name, info);

        auto bodyString = info["body"];
        auto parser = new NowParser(bodyString.toString());
        parser.line = bodyString.documentLineNumber;
        this.body = parser.consumeSubProgram();
    }

    override ExitCode doRun(string name, Input input, Output output)
    {
        input.escopo.rootCommand = this;
        return this.body.run(input.escopo, output);
    }
}
