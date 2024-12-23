module now.nodes.boolean.methods;


import std.array;
import std.regex : matchAll, matchFirst;
import std.string;

import now;


template CreateComparisonOperator(string cmdName, string operator)
{
    const string CreateComparisonOperator = "
        booleanMethods[\"" ~ cmdName ~ "\"] = function (Item object, string path, Input input, Output output)
        {
            bool pivot = (cast(Boolean)object).toBool;
            foreach (item; input.popAll)
            {
                bool x = item.toBool();
                output.push(pivot " ~ operator ~ " x);
            }
            return ExitCode.Success;
        };
        booleanMethods[\"" ~ operator ~ "\"] = booleanMethods[\"" ~ cmdName ~ "\"];
        ";
}

// Methods:
static this()
{
    mixin(CreateComparisonOperator!("eq", "=="));
    mixin(CreateComparisonOperator!("neq", "!="));

    booleanMethods["||"] = function (Item object, string path, Input input, Output output)
    {
        if (object.toBool)
        {
            output.push(true);
            return ExitCode.Success;
        }
        foreach (item; input.popAll)
        {
            if (item.toBool())
            {
                output.push(true);
                return ExitCode.Success;
            }
        }
        output.push(false);
        return ExitCode.Success;
    };
    booleanMethods["&&"] = function (Item object, string path, Input input, Output output)
    {
        if (!object.toBool)
        {
            output.push(false);
            return ExitCode.Success;
        }
        foreach (item; input.popAll)
        {
            if (!item.toBool())
            {
                output.push(false);
                return ExitCode.Success;
            }
        }
        output.push(true);
        return ExitCode.Success;
    };
    booleanMethods["then"] = function(Item object, string path, Input input, Output output)
    {
        /*
        o false
            | :: then {print "it's true!"}
            | :: else {print "it's actually false!"}
        */
        bool isConditionTrue = (cast(Boolean)object).toBool;
        auto thenBody = input.pop!SubProgram;
        auto elseBody = input.pop!SubProgram(null);
        ExitCode exitCode;
        if (isConditionTrue)
        {
            return thenBody.run(input.escopo, output);
        }
        else if (elseBody !is null)
        {
            return elseBody.run(input.escopo, output);
        }
        return ExitCode.Success;
    };
    booleanMethods["else"] = function(Item object, string path, Input input, Output output)
    {
        bool isConditionTrue = (cast(Boolean)object).toBool;
        auto elseBody = input.pop!SubProgram;
        if (!isConditionTrue)
        {
            return elseBody.run(input.escopo, output);
        }
        return ExitCode.Success;
    };
    booleanMethods["assert"] = function(Item object, string path, Input input, Output output)
    {
        bool isConditionTrue = (cast(Boolean)object).toBool;
        string classe = "assertion_error";
        foreach (item; input.popAll)
        {
            if (item.type == ObjectType.String)
            {
                classe = item.toString;
            }
            else
            {
                throw new InvalidArgumentsException(
                    input.escopo,
                    path ~ " should receive only one string as argument.",
                    -1,
                    item
                );
            }
        }

        if (!isConditionTrue)
        {
            throw new AssertionError(
                input.escopo,
                classe,
                -1,
                object
            );
        }
        return ExitCode.Success;
    };
}
