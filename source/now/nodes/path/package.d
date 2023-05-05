module now.nodes.path;

import now;


MethodsMap pathMethods;


class Path : Item
{
    string path;

    this(string path)
    {
        this.path = path;
        this.type = ObjectType.Path;
        this.typeName = "path";
        this.methods = pathMethods;
    }
    override string toString()
    {
        return "path " ~ this.path;
    }
}


class PathFileRange : Item
{
    File file;
    File.ByLine!(char, char) range;
    this(Path path)
    {
        this.type = ObjectType.Range;
        this.typeName = "path_file_range";

        this.file = File(path.path);
        this.range = file.byLine();
    }
    override string toString()
    {
        return "PathFileRange";
    }
    override ExitCode next(Escopo escopo, Output output)
    {
        auto line = range.front;
        if (line is null)
        {
            return ExitCode.Break;
        }
        else
        {
            output.push(line.to!string);
            range.popFront;
            return ExitCode.Continue;
        }
    }
}
