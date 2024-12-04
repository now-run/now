import now;

 import core.runtime;

extern (C) void loadPackage(Document document, ref CommandsMap commands)
{
    stderr.writeln("hello> Init...");
    auto success = Runtime.initialize();
    assert(success);

    stderr.writeln("hello> Loading...");
    commands["hellow"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            auto s = item.toString;
            writeln("Hellow, ", s, "!");
        }
        return ExitCode.Success;
    };
    stderr.writeln("hello> Done.");
}
