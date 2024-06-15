module now.nodes.integer.methods;


import now;


// Operators
template CreateOperator(string cmdName, string operator)
{
    const string CreateOperator = "
        integerMethods[\"" ~ cmdName ~ "\"] = function (Item object, string path, Input input, Output output)
        {
            long result = (cast(Integer)object).toLong;
            foreach (item; input.popAll)
            {
                result = result " ~ operator ~ " item.toLong();
            }
            output.push(result);
            return ExitCode.Success;
        };
        integerMethods[\"" ~ operator ~ "\"] = integerMethods[\"" ~ cmdName ~ "\"];
        ";
}
template CreateComparisonOperator(string cmdName, string operator)
{
    const string CreateComparisonOperator = "
        integerMethods[\"" ~ cmdName ~ "\"] = function (Item object, string path, Input input, Output output)
        {
            long pivot = (cast(Integer)object).toLong;
            foreach (item; input.popAll)
            {
                long x = item.toLong();
                if (!(pivot " ~ operator ~ " x))
                {
                    output.push(false);
                    return ExitCode.Success;
                }
                pivot = x;
            }
            output.push(true);
            return ExitCode.Success;
        };
        integerMethods[\"" ~ operator ~ "\"] = integerMethods[\"" ~ cmdName ~ "\"];
        ";
}


// Methods:
static this()
{
    integerMethods["to.char"] = function (Item object, string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            long x = item.toLong();
            output.push(to!string(cast(char)x));
        }
        return ExitCode.Success;
    };
    integerMethods["to.ascii"] = function (Item object, string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            long l = item.toLong();
            char c = cast(char)(l);
            string s = "" ~ c;
            output.push(s);
        }
        return ExitCode.Success;
    };

    mixin(CreateOperator!("sum", "+"));
    mixin(CreateOperator!("add", "+"));
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
