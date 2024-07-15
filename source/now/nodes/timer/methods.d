module now.nodes.timer.methods;

import now;


static this()
{
    timerMethods["seconds"] = function(Item object, string path, Input input, Output output) {
        auto timer = cast(Timer)object;
        output.push(timer.sw.peek().total!"seconds");
        return ExitCode.Success;
    };
    timerMethods["msecs"] = function(Item object, string path, Input input, Output output) {
        auto timer = cast(Timer)object;
        output.push(timer.sw.peek().total!"msecs");
        return ExitCode.Success;
    };
    timerMethods["usecs"] = function(Item object, string path, Input input, Output output) {
        auto timer = cast(Timer)object;
        output.push(timer.sw.peek().total!"usecs");
        return ExitCode.Success;
    };
    timerMethods["nsecs"] = function(Item object, string path, Input input, Output output) {
        auto timer = cast(Timer)object;
        output.push(timer.sw.peek().total!"nsecs");
        return ExitCode.Success;
    };
    timerMethods["reset"] = function(Item object, string path, Input input, Output output) {
        auto timer = cast(Timer)object;
        timer.sw.reset();
        return ExitCode.Success;
    };
    timerMethods["start"] = function(Item object, string path, Input input, Output output) {
        auto timer = cast(Timer)object;
        if (!timer.sw.running)
        {
            timer.sw.start();
        }
        return ExitCode.Success;
    };
    timerMethods["stop"] = function(Item object, string path, Input input, Output output) {
        auto timer = cast(Timer)object;
        if (timer.sw.running)
        {
            timer.sw.stop();
        }
        return ExitCode.Success;
    };
}
