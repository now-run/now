module now.task;


import std.parallelism : TaskPool, task;

import now;


MethodsMap taskRunMethods;


class TaskRun : Item
{
    bool done = false;
    string path;
    Input input;
    Output output;
    ExitCode exitCode;
    Exception exception;

    this(string path, Input input)
    {
        this.path = path;
        this.input = input;
        this.output = new Output;

        this.type = ObjectType.TaskRun;
        this.typeName = "task_run";
        this.methods = taskRunMethods;
    }
    override string toString()
    {
        return "TaskRun for " ~ path;
    }
}


void fRun(Task t, TaskRun taskRun)
{
    ExitCode exitCode;
    try
    {
        exitCode = t.tRun(taskRun.path, taskRun.input, taskRun.output);
    }
    catch (Exception ex)
    {
        taskRun.exception = ex;
        taskRun.done = true;
        return;
    }
    taskRun.exitCode = exitCode;
    taskRun.done = true;
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
        auto taskRun = new TaskRun(name, input);
        auto t = task!fRun(this, taskRun);
        this.pool.put(t);
        output.push(taskRun);
        return ExitCode.Success;
    }

    ExitCode tRun(string name, Input input, Output output)
    {
        return super.run(name, input, output, false);
    }
}
