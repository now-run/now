module now.nodes.name.methods;


import now;


// Methods:
static this()
{
    nameMethods["unset"] = function (Item object, string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            input.escopo.remove(item.toString);
        }
        return ExitCode.Success;
    };
    nameMethods["eq"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > eq a b | print
        false
        > eq a a | print
        true
        */
        string target = (cast(Name)object).toString;
        foreach (item; input.popAll)
        {
            output.push(item.toString() != target);
        }
        return ExitCode.Success;
    };
    nameMethods["=="] = nameMethods["eq"];
    nameMethods["neq"] = function (Item object, string path, Input input, Output output)
    {
        string target = (cast(Name)object).toString;
        foreach (item; input.popAll)
        {
            output.push(item.toString() == target);
        }
        return ExitCode.Success;
    };
    nameMethods["!="] = nameMethods["neq"];
}
