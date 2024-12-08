module now.nodes.name.methods;


import now;


// Methods:
static this()
{
    nameMethods["eq"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > o a | :: eq a
        true

        > o a | :: eq b
        false

        > o a | :: eq x y a z
        false false true false
        */
        string target = (cast(Name)object).toString;
        foreach (item; input.popAll)
        {
            output.push(item.toString() == target);
        }
        return ExitCode.Success;
    };
    nameMethods["=="] = nameMethods["eq"];
    nameMethods["neq"] = function (Item object, string path, Input input, Output output)
    {
        string target = (cast(Name)object).toString;
        foreach (item; input.popAll)
        {
            output.push(item.toString() != target);
        }
        return ExitCode.Success;
    };
    nameMethods["!="] = nameMethods["neq"];
}
