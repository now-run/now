module now.nodes.floats.methods;


import now;


template CreateOperator(string cmdName, string operator)
{
    const string CreateOperator = "
        floatMethods[\"" ~ cmdName ~ "\"] = function (Item object, string path, Input input, Output output)
        {
            float result = (cast(Float)object).toFloat;
            foreach (item; input.popAll)
            {
                result = result " ~ operator ~ " item.toFloat();
            }
            output.push(result);
            return ExitCode.Success;
        };
        floatMethods[\"" ~ operator ~ "\"] = floatMethods[\"" ~ cmdName ~ "\"];
        ";
}
template CreateComparisonOperator(string cmdName, string operator)
{
    const string CreateComparisonOperator = "
        floatMethods[\"" ~ cmdName ~ "\"] = function (Item object, string path, Input input, Output output)
        {
            float pivot = (cast(Float)object).toFloat;
            foreach (item; input.popAll)
            {
                float x = item.toFloat();
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
        floatMethods[\"" ~ operator ~ "\"] = floatMethods[\"" ~ cmdName ~ "\"];
        ";
}


// Methods:
static this()
{
    mixin(CreateOperator!("sum", "+"));
    mixin(CreateOperator!("sub", "-"));
    mixin(CreateOperator!("mul", "*"));
    mixin(CreateOperator!("div", "/"));
    mixin(CreateOperator!("mod", "%"));

    floatMethods["eq"] = function (Item object, string path, Input input, Output output)
    {
        int pivot = cast(int)((cast(Float)object).toFloat * 1000);
        foreach (item; input.popAll)
        {
            int x = cast(int)(item.toFloat() * 1000);
            if (pivot != x)
            {
                output.push(false);
                return ExitCode.Success;
            }
            pivot = x;
        }
        output.push(true);
        return ExitCode.Success;
    };
    floatMethods["=="] = floatMethods["eq"];

    floatMethods["neq"] = function (Item object, string path, Input input, Output output)
    {
        float pivot = cast(int)(input.pop!float() * 1000);
        foreach (item; input.popAll)
        {
            float x = cast(int)(item.toFloat() * 1000);
            if (pivot == x)
            {
                output.push(false);
                return ExitCode.Success;
            }
            pivot = x;
        }
        output.push(true);
        return ExitCode.Success;
    };
    floatMethods["!="] = floatMethods["neq"];

    mixin(CreateComparisonOperator!("gt", ">"));
    mixin(CreateComparisonOperator!("lt", "<"));
    mixin(CreateComparisonOperator!("gte", ">="));
    mixin(CreateComparisonOperator!("lte", "<="));
}
