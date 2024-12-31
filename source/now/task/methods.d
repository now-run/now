module now.task.methods;


import now;


static this()
{
    taskRunMethods["wait"] = function(Item object, string path, Input input, Output output)
    {
        auto t = cast(TaskRun)object;

        if (!t.done)
        {
            auto ex = new StillRunning(
                input.escopo,
                "The task " ~ t.toString ~ " is still running",
                t,
            );
            ex.classe = "running";
            throw ex;
        }
        else if (t.exception !is null)
        {
            throw t.exception;
        }

        // If the command finished, then fill output with t.output items:
        output.items = t.output.items;
        return t.exitCode;
    };
}
