module now.nodes.timer;


import std.datetime.stopwatch : AutoStart, StopWatch;

import now;


MethodsMap timerMethods;


class Timer : Item
{
    StopWatch sw;

    this()
    {
        this.type = ObjectType.Timer;
        this.methods = timerMethods;

        this.sw = StopWatch(AutoStart.yes);

    }
    override string toString()
    {
        return "Timer";
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
