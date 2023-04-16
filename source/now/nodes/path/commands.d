module now.nodes.path.commands;


import std.datetime : SysTime;
import std.file;
import std.path;

import now.nodes;


Context glob(Context context, SpanMode mode)
{
    auto directory = context.pop!Path();
    auto pattern = context.pop!string();

    Path[] items = directory.path
        .dirEntries(pattern, mode)
        .map!(x => new Path(x))
        .array;
    return context.push(new List(cast(Items)items));
}


static this()
{
    pathCommands["is.file"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        return context.push(path.path.isFile());
    };
    pathCommands["is.dir"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        return context.push(path.path.isDir());
    };
    pathCommands["is.symlink"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        return context.push(path.path.isSymlink());
    };
    pathCommands["exists"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        return context.push(path.path.exists());
    };

    pathCommands["read"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        auto size = size_t.max;
        if (context.size)
        {
            size = context.pop!long();
        }
        auto content = path.path.read(size);
        return context.push(cast(string)content);
    };
    pathCommands["read.lines"] = function (string name, Context context)
    {
        // TODO
        auto path = context.pop!Path();
        return context.error("Not implemented yet", ErrorCode.NotImplemented, "", path);
    };
    pathCommands["write.lines"] = function (string name, Context context)
    {
        // TODO
        auto path = context.pop!Path();
        return context.error("Not implemented yet", ErrorCode.NotImplemented, "", path);
    };
    pathCommands["write"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        foreach (item; context.items)
        {
            auto content = context.pop!string();
            std.file.write(path.path, content);
        }
        return context;
    };
    pathCommands["append"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        foreach (item; context.items)
        {
            auto content = item.toString();
            path.path.append(content);
        }
        return context;
    };
    pathCommands["append.lines"] = function (string name, Context context)
    {
        // TODO
        auto path = context.pop!Path();
        return context.error("Not implemented yet", ErrorCode.NotImplemented, "", path);
    };

    pathCommands["size"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        return context.push(path.path.getSize());
    };
    pathCommands["time"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        SysTime accessTime, modificationTime;
        path.path.getTimes(accessTime, modificationTime);
        return context.push(modificationTime.toUnixTime());
    };

    pathCommands["copy"] = function (string name, Context context)
    {
        auto source = context.pop!Path();
        auto target = context.pop!Path();
        source.path.copy(target.path);
        return context;
    };
    pathCommands["rename"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        auto newName = context.pop!string();
        path.path.rename(newName);
        return context;
    };
    pathCommands["delete"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        try
        {
            path.path.remove();
        }
        catch (FileException)
        {
            // pass
        }
        return context;
    };

    // ---------------------------
    // Directories (generally)
    pathCommands["glob"] = function (string name, Context context)
    {
        return glob(context, SpanMode.shallow);
    };
    pathCommands["glob.depth"] = function (string name, Context context)
    {
        return glob(context, SpanMode.depth);
    };
    pathCommands["glob.breadth"] = function (string name, Context context)
    {
        return glob(context, SpanMode.breadth);
    };
    pathCommands["absolute"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        return context.push(path.path.absolutePath());
    };
    pathCommands["basename"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        return context.push(path.path.baseName());
    };
    pathCommands["dirname"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        return context.push(path.path.dirName());
    };
    pathCommands["extension"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        return context.push(path.path.extension());
    };
    pathCommands["normalize"] = function (string name, Context context)
    {
        auto path = context.pop!Path();
        auto n = path.path.asNormalizedPath();
        return context.push(n.to!string);
    };
}
