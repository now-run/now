module now.nodes.path.methods;


import std.datetime : SysTime;
import std.file;
import std.path;

import now;


ExitCode glob(Item object, Input input, Output output, SpanMode mode)
{
    auto directory = cast(Path)object;
    auto pattern = input.pop!string();

    Path[] items = directory.path
        .dirEntries(pattern, mode)
        .map!(x => new Path(x))
        .array;
    output.push(new List(cast(Items)items));
    return ExitCode.Success;
}


static this()
{
    // About whatever the path points to:
    pathMethods["is.file"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        output.push(path.path.isFile());
            return ExitCode.Success;
    };
    pathMethods["is.dir"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        output.push(path.path.isDir());
            return ExitCode.Success;
    };
    pathMethods["is.symlink"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        output.push(path.path.isSymlink());
            return ExitCode.Success;
    };
    pathMethods["exists"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        output.push(path.path.exists());
            return ExitCode.Success;
    };

    // Operations:
    pathMethods["read"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;

        size_t size = size_t.max;
        auto askedSize = input.pop!long(-1);
        if (askedSize != -1)
        {
            size = cast(size_t)askedSize;
        }

        auto content = path.path.read(size);
        output.push(cast(string)content);
        return ExitCode.Success;
    };
    pathMethods["read.lines"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        output.push(new PathFileRange(path));
        return ExitCode.Success;
    };
    pathMethods["write"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        foreach (item; input.popAll)
        {
            auto content = item.toString();
            std.file.write(path.path, content);
        }
        return ExitCode.Success;
    };
    pathMethods["append"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        foreach (item; input.popAll)
        {
            auto content = item.toString();
            path.path.append(content);
        }
        return ExitCode.Success;
    };

    pathMethods["size"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        output.push(path.path.getSize());
        return ExitCode.Success;
    };
    pathMethods["time"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        SysTime accessTime, modificationTime;
        path.path.getTimes(accessTime, modificationTime);
        output.push(modificationTime.toUnixTime());
        return ExitCode.Success;
    };

    pathMethods["copy"] = function(Item object, string name, Input input, Output output)
    {
        auto source = cast(Path)object;
        auto target = input.pop!Path();
        source.path.copy(target.path);
        return ExitCode.Success;
    };
    pathMethods["rename"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        auto newName = input.pop!string();
        path.path.rename(newName);
        return ExitCode.Success;
    };
    pathMethods["delete"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        try
        {
            path.path.remove();
        }
        catch (FileException)
        {
            // pass
        }
        return ExitCode.Success;
    };

    // On the path itself:
    pathMethods["absolute"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        output.push(path.path.absolutePath());
        return ExitCode.Success;
    };
    pathMethods["basename"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        output.push(path.path.baseName());
        return ExitCode.Success;
    };
    pathMethods["dirname"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        output.push(path.path.dirName());
        return ExitCode.Success;
    };
    pathMethods["extension"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        output.push(path.path.extension());
        return ExitCode.Success;
    };
    pathMethods["normalize"] = function(Item object, string name, Input input, Output output)
    {
        auto path = cast(Path)object;
        auto n = path.path.asNormalizedPath();
        output.push(n.to!string);
        return ExitCode.Success;
    };

    // ---------------------------
    // Directories (generally)
    pathMethods["glob"] = function(Item object, string name, Input input, Output output)
    {
        return glob(object, input, output, SpanMode.shallow);
    };
    pathMethods["glob.depth"] = function(Item object, string name, Input input, Output output)
    {
        return glob(object, input, output, SpanMode.depth);
    };
    pathMethods["glob.breadth"] = function(Item object, string name, Input input, Output output)
    {
        return glob(object, input, output, SpanMode.breadth);
    };
    pathMethods["mkdir"] = function(Item object, string name, Input input, Output output)
    {
        /*
        > path "/tmp/a/b/c" | :: mkdir
        */
        auto path = cast(Path)object;
        try
        {
            path.path.mkdirRecurse();
        }
        catch (FileException)
        {
            throw new PathException(
                input.escopo,
                "Could not create directory",
                -1,
                object
            );
        }
        return ExitCode.Success;
    };
}
