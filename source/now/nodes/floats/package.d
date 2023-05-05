module now.nodes.floats;


import now;


MethodsMap floatMethods;


class Float : Item
{
    // 12.34

    float value;
    this(float value)
    {
        this.value = value;
        this.type = ObjectType.Float;
        this.typeName = "float";
        this.methods = floatMethods;
    }
    override bool toBool()
    {
        return cast(bool)value;
    }
    override long toLong()
    {
        return cast(long)value;
    }
    override float toFloat()
    {
        return value;
    }
    override string toString()
    {
        return value.to!string;
    }

    // Operators:
    Float opUnary(string operator)
    {
        if (operator != "-")
        {
            throw new Exception(
                "Unsupported operator: " ~ operator
            );
        }
        return new Float(-value);
    }
}
