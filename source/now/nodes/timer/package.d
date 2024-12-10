module now.nodes.timer;


import std.datetime.stopwatch : AutoStart, StopWatch;

import now;


MethodsMap timerMethods;


class Timer : Item
{
    StopWatch sw;
    string description;

    this()
    {
        this.type = ObjectType.Timer;
        this.methods = timerMethods;

        this.sw = StopWatch(AutoStart.yes);

    }
    this(string description)
    {
        this();
        this.description = description;
    }
    override string toString()
    {
        if (description !is null)
        {
            return "<Timer: " ~ description ~ ">";
        }
        else
        {
            return "Timer";
        }
    }
    override Item range()
    {
        return this;
    }
    override ExitCode next(Escopo escopo, Output output)
    {
        output.push(this);
        return ExitCode.Continue;
    }
}
