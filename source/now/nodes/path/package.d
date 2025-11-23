module now.nodes.path;

import now;

import core.thread : Thread;
import std.algorithm.mutation : stripRight;
import std.datetime : msecs;


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
    bool stopOnEmpty;
    string delegate() nextLine;

    this(Path path, bool stopOnEmpty=true)
    {
        this(File(path.path), stopOnEmpty);
    }
    this(File file, bool stopOnEmpty=true)
    {
        this.type = ObjectType.Range;
        this.typeName = "path_file_range";
        this.file = file;
        this.stopOnEmpty = stopOnEmpty;
    }
    override string toString()
    {
        return "PathFileRange for file " ~ file.name;
    }
    override ExitCode next(Escopo escopo, Output output)
    {
        log("PathFileRange> next");
        auto position = this.file.tell;
        auto line = this.file.readln;
        if (line.empty)
        {
            log("PathFileRange> line is empty!");
            if (stopOnEmpty)
            {
                return ExitCode.Break;
            }
            else
            {
                Thread.sleep(250.msecs);
                log("PathFileRange> Skip");
                this.file.seek(position);
                return ExitCode.Skip;
            }
        }
        else
        {
            log("PathFileRange> line=", line);
            output.push(line.stripRight('\n'));
            return ExitCode.Continue;
        }
    }
}
