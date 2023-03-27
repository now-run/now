module now.commands.timer;

import std.datetime.stopwatch;

import now.nodes;
import now.commands;


CommandsMap timerCommands;


class Timer : Item
{
    SubProgram callback;
    StopWatch sw;
    this(SubProgram callback)
    {
        this.callback = callback;
        this.sw = StopWatch(AutoStart.no);
        this.commands = timerCommands;
        this.type = ObjectType.Other; // TODO
        this.typeName = "timer";
    }
    void start()
    {
        sw.start();
    }
    Context stop(Context context)
    {
        sw.stop();
        auto seconds = sw.peek().total!"seconds";
        debug {stderr.writeln("  seconds: ", seconds);}
        auto msecs = sw.peek().total!"msecs";
        auto usecs = sw.peek().total!"usecs";
        auto nsecs = sw.peek().total!"nsecs";

        auto newScope = new Escopo(context.escopo);
        newScope["seconds"] = new FloatAtom(seconds);
        newScope["miliseconds"] = new FloatAtom(msecs);
        newScope["microseconds"] = new FloatAtom(usecs);
        newScope["nanoseconds"] = new FloatAtom(nsecs);

        // XXX: this operation definitely could be a nice subroutine for
        // us (me) language developers (developer):
        Items items = context.items;
        context = context.process.run(this.callback, context.next(newScope));
        context.push(items);
        return context;
    }
    override string toString()
    {
        return "timer";
    }
}


void loadTimerCommands(CommandsMap commands)
{
    commands["timer"] = function (string path, Context context)
    {
        /*
        scope "test the timer" {
            timer { print "This scope ran for $seconds seconds" } | autoclose
            sleep 5
        }
        # stderr> This scope ran for 5 seconds
        */
        auto callback = context.pop!SubProgram();
        return context.push(new Timer(callback));
    };
    timerCommands["open"] = function (string path, Context context)
    {
        auto timer = context.pop!Timer();
        timer.start();
        debug {stderr.writeln("timer started");}
        return context;
    };
    timerCommands["close"] = function (string path, Context context)
    {
        debug {stderr.writeln("closing timer");}
        auto timer = context.pop!Timer();
        return timer.stop(context);
    };
}
