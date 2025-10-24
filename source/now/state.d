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

    bool check(List args, Escopo escopo)
    {
        auto output = new Output();
        // auto escopo = new Escopo(document, "state check");
        escopo["state_args"] = args;
        auto exitCode = this.checkProgram.run(escopo, output);
        log("state.", name, ".check.exitCode:", exitCode);
        auto response = cast(Boolean)output.pop;
        log("state response: ", response);
        return response.toBool;
    }
    ExitCode act(List args, Escopo escopo, Output output)
    {
        escopo["state_args"] = args;
        auto exitCode = this.actionProgram.run(escopo, output);
        log("state.", name, ".act.exitCode:", exitCode);
        return exitCode;
    }
    ExitCode run(Items args, Escopo escopo, Output output)
    {
        Items evaluatedArgsItems;
        foreach (stateArg; args)
        {
            evaluatedArgsItems ~= stateArg.evaluate(escopo);
        }

        auto evaluatedArgs = new List(evaluatedArgsItems);
        if (this.check(evaluatedArgs, escopo) == false)
        {
            return this.act(evaluatedArgs, escopo, output);
        }
        else
        {
            return ExitCode.Success;
        }
    }
}
