module now.nodes.boolean;


import now;


MethodsMap booleanMethods;


class Boolean : Item
{
    // true
    // false

    bool value;
    this(bool value)
    {
        this.type = ObjectType.Boolean;
        this.typeName = "boolean";
        this.methods = booleanMethods;

        this.value = value;
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
}
