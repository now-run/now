module now.nodes.strings;


import now;


MethodsMap stringMethods;


// A string without substitutions:
class String : Item
{
    string repr;

    this(string s)
    {
        this.repr = s;
        this.type = ObjectType.String;
        this.typeName = "string";
        this.methods = stringMethods;
    }

    // Conversions:
    override string toString()
    {
        return this.repr;
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

    override Items evaluate(Escopo escopo)
    {
        string result;

        foreach(part; parts)
        {
            foreach(item; part.evaluate(escopo))
            {
                result ~= item.toString();
            }
        }

        return [new String(result)];
    }
}
