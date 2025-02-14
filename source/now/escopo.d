module now.escopo;


import now;


class Escopo : Dict
{
    Escopo parent;
    string name;
    BaseCommand rootCommand;
    Document document;

    this(Escopo parent, string name)
    {
        super();
        log(": Escopo: ", name);
        this.name = name;
        this.parent = parent;

        if (parent !is null)
        {
            // Child scopes always share variables:
            this.values = parent.values;
            this.needsReordering = true;

            this.rootCommand = parent.rootCommand;
            this.document = parent.document;
        }

        log(":: Escopo created.");
    }
    this(Document document, string name, BaseCommand rootCommand=null)
    {
        this(cast(Escopo)null, name);
        this.document = document;
        this.rootCommand = rootCommand;
    }

    Escopo addPathEntry(string name)
    {
        return new Escopo(this, name);
    }

    override string toString()
    {
        string[] names = [name];
        auto pivot = this;
        while (pivot.parent !is null)
        {
            pivot = pivot.parent;
            names ~= pivot.name;
        }
        return names.retro.join("/");
    }

    /*
    Behave as a Dict, but if a key is missing,
    try to find it in this.document.
    */
    override Item opIndex(string k)
    {
        auto v = values.get(k, null);
        if (v is null && this.parent !is null)
        {
            return this.parent[k];
        }
        if (v is null && document !is null)
        {
            v = document.get(k, null);
        }
        if (v is null)
        {
            throw new VariableNotFoundException(
                this,
                "variable " ~ k ~ " not found",
                new String(k),
            );
        }

        return v;
    }
}
