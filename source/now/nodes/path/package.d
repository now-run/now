module now.nodes.path;

import now;

import std.algorithm.mutation : stripRight;


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
        /*
        Remember we use toString to generate
        usable string IN USERLAND, so don't
        try to get fancy here.
        */
        return this.path;
    }
}


class PathFileRange : Item
{
    File file;
    string delegate() nextLine;

    this(Path path)
    {
        this.type = ObjectType.Range;
        this.typeName = "path_file_range";
        this.file = File(path.path);
    }
    override string toString()
    {
        return "PathFileRange";
    }
    override ExitCode next(Escopo escopo, Output output)
    {
        auto line = this.file.readln();
        if (line.empty)
        {
            return ExitCode.Break;
        }
        else
        {
            output.push(line.stripRight('\n'));
            return ExitCode.Continue;
        }
    }
}
