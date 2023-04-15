module now.nodes.strings;


import now.nodes;


CommandsMap stringCommands;


// A string without substitutions:
class String : Item
{
    string repr;

    this(string s)
    {
        this.repr = s;
        this.type = ObjectType.String;
        this.typeName = "string";
        this.commands = stringCommands;
    }

    // Conversions:
    override string toString()
    {
        return this.repr;
    }

    override Context evaluate(Context context)
    {
        context.push(this);
        return context;
    }

    template opCast(T : string)
    {
        string opCast()
        {
            return this.repr;
        }
    }
    template opUnary(string operator)
    {
        override Item opUnary()
        {
            string newRepr;
            string repr = to!string(this);
            if (repr[0] == '-')
            {
                newRepr = repr[1..$];
            }
            else
            {
                newRepr = "-" ~ repr;
            }
            return new String(newRepr);
        }
    }

    byte[] toBytes()
    {
        byte[] bytes;

        string s = this.toString();
        foreach (c; s)
        {
            bytes ~= cast(byte)c;
        }

        return bytes;
    }
}


// A string with substitutions:
class SubstString : String
{
    Items parts;

    this(Items parts)
    {
        super("");
        this.parts = parts;
        this.type = ObjectType.String;
    }

    // Operators:
    override string toString()
    {
        return to!string(this.parts
            .map!(x => to!string(x))
            .join(""));
    }

    override Context evaluate(Context context)
    {
        string result;
        string value;

        foreach(part; parts)
        {
            context = part.evaluate(context);
            if (context.exitCode == ExitCode.Failure)
            {
                return context;
            }
            result ~= context.pop().toString();
        }

        return context.push(new String(result));
    }
}
