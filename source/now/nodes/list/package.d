module now.nodes.list;


import now;


MethodsMap listMethods;


class List : Item
{
    Items items;

    this(Items items)
    {
        this.methods = listMethods;
        this.type = ObjectType.List;
        this.typeName = "list";
        this.items = items;
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return "(" ~ to!string(this.items
            .map!(x => to!string(x))
            .join(" , ")) ~ ")";
    }
}

class Pair : List
{
    this(Items items)
    {
        if (items.length != 2)
        {
            throw new InvalidException(
                null,
                "Pairs can only have 2 items"
            );
        }
        super(items);
        this.type = ObjectType.Pair;
        this.typeName = "pair";
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return "(" ~ to!string(this.items
            .map!(x => to!string(x))
            .join(" = ")) ~ ")";
    }
}
