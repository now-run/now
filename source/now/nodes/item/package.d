module now.nodes.item;


import std.variant;

import now.nodes;


// A base class for all kind of items that
// compose a Sequence:
class Item
{
    ObjectType type;
    string typeName;
    CommandsMap commands;

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
    long toInt()
    {
        auto thisInfo = typeid(this);
        throw new Exception(
            "Conversion from "
            ~ thisInfo.toString() ~ " to int not implemented."
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
    Context evaluate(Context context, bool force)
    {
        return this.evaluate(context);
    }
    Context evaluate(Context context)
    {
        context.push(this);
        return context;
    }
    Context next(Context context)
    {
        context = runMethod("next", context);
        return context;
    }

    Context runMethod(string name, Context context)
    {
        auto cmdPtr = (name in this.commands);
        if (cmdPtr !is null)
        {
            auto cmd = *cmdPtr;
            context.push(this);
            return cmd(name, context);
        }
        else
        {
            context.push(this);
            return context.program.runCommand(name, context);
        }
        /*
        else
        {
            auto info = typeid(this);
            string msg = 
                name
                ~ " not implemented for "
                ~ info.toString();
            return context.error(msg, ErrorCode.NotImplemented, "");
        }
        */
    }

    Context runCommand(string name, Context context)
    {
        auto cmdPtr = (name in this.commands);
        if (cmdPtr !is null)
        {
            auto cmd = *cmdPtr;
            return cmd(name, context);
        }
        else
        {
            return context.program.runCommand(name, context);
        }
        /*
        else
        {
            auto info = typeid(this);
            string msg = 
                name
                ~ " not implemented for "
                ~ info.toString();
            return context.error(msg, ErrorCode.NotImplemented, "");
        }
        */
    }
}
