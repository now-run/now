module now.nodes.item;


import std.variant;

import now;


// A base class for all kind of items that
// compose a Sequence:
class Item
{
    ObjectType type;
    string typeName;
    MethodsMap methods;

    // Operators:
    template opUnary(string operator)
    {
        Item opUnary()
        {
            throw new Exception(
                "Cannot apply " ~ operator ~ " to " ~ this.toString()
            );
        }
    }

    // Conversions:
    bool toBool()
    {
        auto thisInfo = typeid(this);
        throw new Exception(
            "Conversion from "
            ~ thisInfo.toString() ~ " to bool not implemented."
        );
    }
    long toLong()
    {
        auto thisInfo = typeid(this);
        throw new Exception(
            "Conversion from "
            ~ thisInfo.toString() ~ " to long not implemented."
            ~ " (" ~ this.toString() ~ ")"
        );
    }
    float toFloat()
    {
        auto thisInfo = typeid(this);
        throw new Exception(
            "Conversion from "
            ~ thisInfo.toString() ~ " to float not implemented."
        );
    }
    override string toString()
    {
        auto thisInfo = typeid(this);
        throw new Exception(
            "Conversion from "
            ~ thisInfo.toString() ~ " to string not implemented."
        );
    }

    // Evaluation:
    Items evaluate(Escopo escopo)
    {
        return [this];
    }
    ExitCode next(Escopo escopo, Output output)
    {
        auto input = Input(
            escopo,
            [], [], null
        );
        return runMethod("next", input, output);
    }

    bool hasMethod(string name)
    {
        auto cmdPtr = (name in this.methods);
        return (cmdPtr !is null);
    }
    ExitCode runMethod(string name, Input input, Output output)
    {
        if (auto cmdPtr = (name in this.methods))
        {
            auto cmd = *cmdPtr;
            return cmd(this, name, input, output);
        }
        else
        {
            throw new NotFoundException(
                input.escopo,
                "Method `" ~ name ~ "` not found"
                ~ " for type " ~ type.to!string
            );
        }
    }
}
