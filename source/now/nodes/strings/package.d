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

// Part of a SubstString
class StringPart
{
    string value;
    bool isName;
    this(string value, bool isName)
    {
        this.value = value;
        this.isName = isName;
    }
    this(char[] chr, bool isName)
    {
        this(cast(string)chr, isName);
    }
}


// A string with substitutions:
class SubstString : String
{
    StringPart[] parts;

    this(StringPart[] parts)
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
            if (part.isName)
            {
                Items values;
                try
                {
                    values = context.escopo[part.value];
                }
                catch (NotFoundException)
                {
                    auto msg = "Variable " ~ to!string(part.value) ~ " is not set";
                    return context.error(msg, ErrorCode.InvalidArgument, "");
                }

                debug{stderr.writeln("StringPart.evaluate.values:", values);}
                foreach (v; values)
                {
                    auto newContext = v.runMethod(
                        "to.string", context.next()
                    );
                    if (newContext.exitCode == ExitCode.Failure)
                    {
                        return newContext;
                    }
                    auto resultItems = newContext.items;
                    debug{
                        stderr.writeln("StringPart.evaluate.resultItems:", resultItems);
                    }
                    result ~= to!string(resultItems
                        .map!(x => to!string(x))
                        .join(" "));
                    }
            }
            else
            {
                result ~= part.value;
            }
        }

        debug{stderr.writeln(">>> StringPart.evaluate.result:", result);}
        return context.push(new String(result));
    }
}
