module now.nodes.subprogram;


import now;


MethodsMap subprogramMethods;


class SubProgram : Item
{
    Pipeline[] pipelines;

    this(Pipeline[] pipelines)
    {
        this.pipelines = pipelines;
        this.type = ObjectType.SubProgram;
        this.typeName = "subprogram";
        this.methods = subprogramMethods;
    }

    override string toString()
    {
        string s = "";
        if (pipelines.length < 2)
        {
            foreach (pipeline; pipelines)
            {
                s ~= pipeline.toString();
            }
        }
        else
        {
            s ~= "{\n";
            foreach (pipeline; pipelines)
            {
                s ~= pipeline.toString() ~ "\n";
            }
            s ~= "}";
        }
        return s;
    }

    ExitCode run(Escopo escopo, Output output)
    {
        return run(escopo, [], output);
    }
    ExitCode run(Escopo escopo, Items inputs, Output output)
    {
        auto exitCode = ExitCode.Success;

        log("- SubProgram.run: ", inputs, output);

        // init
        SubProgram init;
        Output initOutput;
        if (auto initRef = ("init" in properties))
        {
            init = cast(SubProgram)((*initRef).evaluate(escopo).front);
            initOutput = new Output();
            auto initExitCode = init.run(escopo, initOutput);
            // TODO: what to do with initExitCode?
        }

        // progress
        SubProgram progress;
        Output progressOutput;
        if (auto progressRef = ("progress" in properties))
        {
            progress = cast(SubProgram)((*progressRef).evaluate(escopo).front);
            progressOutput = new Output();
        }

        // finish
        scope(exit) {
            SubProgram finish;
            Output finishOutput;
            if (auto finishRef = ("finish" in properties))
            {
                finish = cast(SubProgram)((*finishRef).evaluate(escopo).front);
                finishOutput = new Output();
                auto finishExitCode = finish.run(escopo, finishOutput);
                // XXX: should the exit code be handled?
            }
        }

        foreach (pipeline; pipelines)
        {
            // Helper for progress bars, etc:
            if (progress !is null)
            {
                auto progressExitCode = progress.run(escopo, progressOutput);
                // XXX: should the exit code be handled?
            }

            // No output will be shared:
            output.items.length = 0;
            exitCode = pipeline.run(escopo, inputs, output);

            // We can't share `inputs` with the next pipelines!
            inputs = [];

            final switch(exitCode)
            {
                case ExitCode.Success:
                case ExitCode.Inject:
                    // That is the expected result from Pipelines:
                    break;

                // -----------------
                // Proc execution:
                case ExitCode.Return:
                    // Return should keep stopping
                    // processes until properly
                    // handled.
                    return exitCode;

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                case ExitCode.Skip:
                    return exitCode;
            }
        }

        return exitCode;
    }

}
