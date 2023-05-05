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
            this.order = parent.order;
            this.values = parent.values;

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

    Escopo createChild(string name)
    {
        return new Escopo(this, name);
    }

    override string toString()
    {
        return "Escopo " ~ name;
    }

    /*
    Behave as a Dict, but if a key is missing,
    try to find it in this.document.
    */
    override Item opIndex(string k)
    {
        auto v = values.get(k, null);
        if (v is null && document !is null)
        {
            v = document.get(k, null);
        }
        if (v is null)
        {
            throw new NotFoundException(this, "key " ~ k ~ " not found");
        }

        return v;
    }
}
