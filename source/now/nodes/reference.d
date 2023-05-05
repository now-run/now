module now.nodes.reference;


import now;


class Reference : Name
{
    // $x

    this(string s)
    {
        super(s);
        this.type = ObjectType.Reference;
        this.typeName = "reference";
    }

    override Items evaluate(Escopo escopo)
    {
        auto v = escopo[value];
        if (v.type == ObjectType.Sequence)
        {
            return (cast(Sequence)v).items;
        }
        else
        {
            return [v];
        }
    }
}
