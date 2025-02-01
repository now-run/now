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
    Item[string] properties;
    size_t documentLineNumber;
    size_t documentColNumber;

    // Operators:
    template opUnary(string operator)
    {
        Item opUnary()
        {
            throw new InvalidOperatorException(
                null,
                "Cannot apply " ~ operator ~ " to " ~ this.toString(),
                -1,
                this
            );
        }
    }

    // Conversions:
    bool toBool()
    {
        auto thisInfo = typeid(this);
        throw new NotImplementedException(
            null,
            "Conversion from "
            ~ thisInfo.toString() ~ " to bool not implemented.",
            -1,
            this
        );
    }
    long toLong()
    {
        auto thisInfo = typeid(this);
        throw new NotImplementedException(
            null,
            "Conversion from "
            ~ thisInfo.toString() ~ " to long not implemented."
            ~ " (" ~ this.toString() ~ ")",
            -1,
            this
        );
    }
    float toFloat()
    {
        auto thisInfo = typeid(this);
        throw new NotImplementedException(
            null,
            "Conversion from "
            ~ thisInfo.toString() ~ " to float not implemented.",
            -1,
            this
        );
    }
    override string toString()
    {
        auto thisInfo = typeid(this);
        throw new NotImplementedException(
            null,
            "Conversion from "
            ~ thisInfo.toString() ~ " to string not implemented.",
            -1,
            this
        );
    }

    // Evaluation:
    Items evaluate(Escopo escopo)
    {
        return [this];
    }

    // Iteration:
    Item range()
    {
        if (this.type == ObjectType.Range)
        {
            return this;
        }
        else
        {
            return new ItemsRange([this]);
        }
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
            throw new MethodNotFoundException(
                input.escopo,
                "Method `" ~ name ~ "` not found"
                ~ " for type " ~ type.to!string
                ~ "; object: " ~ this.toString
            );
        }
    }
}

class ItemsRange : Item
{
    Items items;
    size_t index;
    this(Items items)
    {
        this.type = ObjectType.Range;
        this.typeName = "items_range";

        this.items = items;
        this.index = 0;
    }

    override ExitCode next(Escopo escopo, Output output)
    {
        if (index >= items.length)
        {
            return ExitCode.Break;
        }

        output.push(items[index++]);
        return ExitCode.Continue;
    }
    override string toString()
    {
        return "<ItemsRange: " ~ to!string(this.items
            .map!(x => to!string(x))
            .join(" , ")) ~ ">";
    }
}

class ItemsRangesRange : Item
{
    Items ranges;
    size_t index;

    this(Items items)
    {
        foreach (item; items)
        {
            this.ranges ~= item.range();
        }
    }
    override ExitCode next(Escopo escopo, Output output)
    {
        if (index >= ranges.length)
        {
            return ExitCode.Break;
        }

        auto range = ranges[index];
        auto exitCode = range.next(escopo, output);
        if (exitCode == ExitCode.Break)
        {
            index++;
            exitCode = ExitCode.Continue;
        }
        return exitCode;
    }
    override string toString()
    {
        return "<ItemsRangesRange: " ~ to!string(this.ranges
            .map!(x => to!string(x))
            .join(" , ")) ~ ">";
    }
}
