module now.nodes.integer;


import now;


MethodsMap integerMethods;


class Integer : Item
{
    // 10

    long value;

    this(long value)
    {
        this.value = value;
        this.type = ObjectType.Integer;
        this.typeName = "integer";
        this.methods = integerMethods;
    }
    Integer opUnary(string operator)
    {
        if (operator != "-")
        {
            throw new Exception(
                "Unsupported operator: " ~ operator
            );
        }
        return new Integer(-value);
    }

    override bool toBool()
    {
        return cast(bool)value;
    }
    override long toLong()
    {
        return value;
    }
    override float toFloat()
    {
        return cast(float)value;
    }
    override string toString()
    {
        return to!string(value);
    }
}

