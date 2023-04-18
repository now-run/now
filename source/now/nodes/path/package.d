module now.nodes.path;

import now.nodes;


CommandsMap pathCommands;


class Path : Item
{
    string path;

    this(string path)
    {
        this.path = path;
        this.type = ObjectType.Path;
        this.typeName = "path";
        this.commands = pathCommands;
    }
    override string toString()
    {
        return this.path;
    }
}


class PathFileRange : Item
{
    File file;
    File.ByLine!(char, char) range;
    this(Path path)
    {
        this.file = File(path.path);
        this.range = file.byLine();
    }
    override string toString()
    {
        return "PathFileRange";
    }
    override Context next(Context context)
    {
        auto line = range.front;
        if (line is null)
        {
            context.exitCode = ExitCode.Break;
        }
        else
        {
            range.popFront;

            context.push(line.to!string);
            context.exitCode = ExitCode.Continue;
        }
        return context;
    }
}
