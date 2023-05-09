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
            foreach(pipeline; pipelines)
            {
                s ~= pipeline.toString();
            }
        }
        else
        {
            s ~= "{\n";
            foreach(pipeline; pipelines)
            {
                s ~= pipeline.toString() ~ "\n";
            }
            s ~= "}";
        }
        return s;
    }

    // From "process.d":
    ExitCode run(Escopo escopo, Output output)
    {
        return run(escopo, output, []);
    }
    ExitCode run(Escopo escopo, Output output, Items inputs)
    {
        auto exitCode = ExitCode.Success;

        foreach(pipeline; pipelines)
        {
            try
            {
                exitCode = pipeline.run(escopo, output, inputs);
            }
            catch (Exception ex)
            {
                stderr.writeln(
                    "Exception ", ex,
                    " on Pipeline ", this
                );
                throw ex;
            }

            final switch(exitCode)
            {
                case ExitCode.Success:
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
