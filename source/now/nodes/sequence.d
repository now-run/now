module now.nodes.sequence;


import now;


class Sequence : Item
{
    Items items;

    this(Items items)
    {
        this.type = ObjectType.Sequence;
        this.items = items;
    }

    override string toString()
    {
        return "<Sequence: " ~ items.map!(x => x.toString()).join(" ") ~ ">";
    }

    override Items evaluate(Escopo escopo)
    {
        log("- Sequence.evaluate: ", items);
        return items;
    }
}
