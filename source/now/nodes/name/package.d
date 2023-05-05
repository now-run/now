module now.nodes.name;


import now;

MethodsMap nameMethods;


class Name : Item
{
    // x

    string value;

    this(string s)
    {
        this.type = ObjectType.Name;
        this.value = s;
        this.methods = nameMethods;
        this.typeName = "atom";
    }

    // Utilities and operators:
    override string toString()
    {
        return this.value;
    }
}
