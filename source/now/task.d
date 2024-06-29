module now.task;

import std.parallelism : TaskPool, task;

import now;


void fRun(Task t, string name, Input input, Output output)
{
    t.tRun(name, input, output);
}


class Task : Procedure
{
    TaskPool pool;
    this(string name, Dict info, TaskPool pool)
    {
        super(name, info);
        this.pool = pool;
    }

    override ExitCode run(string name, Input input, Output output, bool keepScope=false)
    {
        // TODO: find a less convoluted way of running this,
        // without an external function to "bridge" things...
        auto t = task!fRun(this, name, input, output);
        this.pool.put(t);
        return ExitCode.Success;
    }

    void tRun(string name, Input input, Output output)
    {
        super.run(name, input, output, false);
    }
}
