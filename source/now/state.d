module now.state;

import now.grammar;
import now.escopo;
import now.nodes;


class State
{
    Document document;
    string name;
    SubProgram checkProgram;
    SubProgram actionProgram;

    this(Document document, string name, Dict checkInfo, Dict actionInfo)
    {
        this.document = document;
        this.name = name;

        auto parser = new NowParser(checkInfo["body"].toString);
        this.checkProgram = parser.consumeSubProgram;

        parser = new NowParser(actionInfo["body"].toString);
        this.actionProgram = parser.consumeSubProgram;
    }

    bool check(List args)
    {
        auto output = new Output();
        auto escopo = new Escopo(document, "state check");
        escopo["args"] = args;
        auto exitCode = this.checkProgram.run(escopo, output);
        log("state.", name, ".check.exitCode:", exitCode);
        auto response = cast(Boolean)output.pop;
        log("state response: ", response);
        return response.toBool;
    }
    ExitCode act(List args)
    {
        auto output = new Output();
        auto escopo = new Escopo(document, "state action");
        escopo["args"] = args;
        auto exitCode = this.actionProgram.run(escopo, output);
        log("state.", name, ".act.exitCode:", exitCode);
        return exitCode;
    }
    void run(List args)
    {
        if (this.check(args) == false)
        {
            this.act(args);
        }
    }
}
