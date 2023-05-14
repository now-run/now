module now.nodes.execlist;


import now;


class ExecList : Item
{
    SubProgram subprogram;

    this(SubProgram subprogram)
    {
        this.subprogram = subprogram;
        this.type = ObjectType.ExecList;
    }

    override string toString()
    {
        return "[" ~ this.subprogram.toString() ~ "]";
    }
    override Items evaluate(Escopo escopo)
    {
        auto newScope = escopo.addPathEntry("ExecList");
        auto output = new Output;
        this.subprogram.run(newScope, output);
        return output.items;
    }
}
