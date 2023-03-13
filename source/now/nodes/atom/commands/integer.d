module now.nodes.atom.commands.integer;


import now.nodes;


// Operators
template CreateOperator(string cmdName, string operator)
{
    const string CreateOperator = "
        integerCommands[\"" ~ cmdName ~ "\"] = function (string path, Context context)
        {
            if (context.size < 2)
            {
                auto msg = \"`\" ~ path ~ \"` expects at least 2 arguments\";
                return context.error(msg, ErrorCode.InvalidArgument, \"int\");
            }

            long result = context.pop!long();
            foreach (item; context.items)
            {
                result = result " ~ operator ~ " item.toInt();
            }
            return context.push(result);
        };
        integerCommands[\"" ~ operator ~ "\"] = integerCommands[\"" ~ cmdName ~ "\"];
        ";
}
template CreateComparisonOperator(string cmdName, string operator)
{
    const string CreateComparisonOperator = "
        integerCommands[\"" ~ cmdName ~ "\"] = function (string path, Context context)
        {
            if (context.size < 2)
            {
                auto msg = \"`\" ~ path ~ \"` expects at least 2 arguments\";
                return context.error(msg, ErrorCode.InvalidArgument, \"int\");
            }

            long pivot = context.pop!long();
            foreach (item; context.items)
            {
                long x = item.toInt();
                if (!(pivot " ~ operator ~ " x))
                {
                    return context.push(false);
                }
                pivot = x;
            }
            return context.push(true);
        };
        integerCommands[\"" ~ operator ~ "\"] = integerCommands[\"" ~ cmdName ~ "\"];
        ";
}


// Ranges
class IntegerRange : Item
{
    long start = 0;
    long limit = 0;
    long step = 1;
    long current = 0;
    bool silent = false;

    this(long limit)
    {
        this.limit = limit;
        this.type = ObjectType.Range;
        this.typeName = "integer_range";
    }
    this(long start, long limit)
    {
        this(limit);
        this.current = start;
        this.start = start;
    }
    this(long start, long limit, long step)
    {
        this(start, limit);
        this.step = step;
    }

    override string toString()
    {
        return
            "range.integer("
            ~ to!string(start)
            ~ ","
            ~ to!string(limit)
            ~ ")";
    }

    override Context next(Context context)
    {
        long value = current;
        if (value > limit)
        {
            context.exitCode = ExitCode.Break;
        }
        else
        {
            if (!silent)
            {
                context.push(value);
            }
            context.exitCode = ExitCode.Continue;
        }
        current += step;
        return context;
    }
}



// Commands:
static this()
{
    integerCommands["range"] = function (string path, Context context)
    {
        /*
        > range 10       # [zero, 10]
        > range 10 20    # [10, 20]
        > range 10 14 2  # 10 12 14
        */
        auto start = context.pop!long();
        long limit = 0;
        if (context.size)
        {
            limit = context.pop!long();
        }
        else
        {
            // zero to...
            limit = start;
            start = 0;
        }
        if (start > limit)
        {
            auto msg = "Invalid range";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        long step = 1;
        if (context.size)
        {
            step = context.pop!long();
        }

        auto range = new IntegerRange(start, limit, step);
        range.silent = (path == "range.silent");

        return context.push(range);
    };
    /*
    A "silent" range does not push the current value into the stack.
    > range.silent 10 | { stack.pop | print }
    # pop 10 "actual" items from the stack.
    */
    integerCommands["range.silent"] = integerCommands["range"];

    integerCommands["to.char"] = function (string path, Context context)
    {
        foreach (item; context.items)
        {
            long x = item.toInt();
            context.push(to!string(cast(char)x));
        }
        return context;
    };
    integerCommands["to.ascii"] = function (string path, Context context)
    {
        foreach (item; context.items)
        {
            long l = item.toInt();
            char c = cast(char)(l);
            string s = "" ~ c;
            context.push(s);
        }
        return context;
    };

    mixin(CreateOperator!("sum", "+"));
    mixin(CreateOperator!("sub", "-"));
    mixin(CreateOperator!("mul", "*"));
    mixin(CreateOperator!("div", "/"));
    mixin(CreateOperator!("mod", "%"));
    mixin(CreateComparisonOperator!("eq", "=="));
    mixin(CreateComparisonOperator!("neq", "!="));
    mixin(CreateComparisonOperator!("gt", ">"));
    mixin(CreateComparisonOperator!("lt", "<"));
    mixin(CreateComparisonOperator!("gte", ">="));
    mixin(CreateComparisonOperator!("lte", "<="));
}
