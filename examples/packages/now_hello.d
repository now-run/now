import std.stdio;

import now.nodes;
import rt.dmain2 : rt_init;


extern (C) void init(Program program)
{
    /*
    We "should" call `rt_term` when the package is unloaded,
    but no package-unload process is envisioned at the
    moment, so... we MAY BE okay with
    only `rt_init`...
    */
    rt_init();

    program.globalCommands["hellow"] = function (string path, Context context)
    {
        string name = context.pop!string();
        stdout.writeln("Hellow, ", name, "!");
        return context;
    };
}
