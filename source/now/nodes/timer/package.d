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
}
