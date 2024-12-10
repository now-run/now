module now.nodes.error;


import now;


MethodsMap errorMethods;


class Erro : Item
{
    int code = -1;
    string classe;
    Item subject;
    Escopo escopo;
    NowException exception;

    this(
        string typeName, string classe,
        Escopo escopo=null, Item subject=null,
        int code=-1
    )
    {
        this(typeName, classe, escopo, subject, null, code);
    }
    this(
        string typeName, string classe,
        Escopo escopo=null, Item subject=null,
        NowException ex=null, int code=-1
    )
    {
        this.typeName = typeName;
        this.classe = classe;
        this.escopo = escopo;
        this.subject = subject;
        this.code = code;

        this.type = ObjectType.Error;
        this.exception = ex;

        this.methods = errorMethods;
    }

    // Conversions:
    override string toString()
    {
        string s = "Error";

        if (code != -1)
        {
            s ~= " " ~ to!string(code);
        }
        s ~= ": " ~ typeName;

        if (classe)
        {
            s ~= ": <" ~ classe ~ ">";
        }
        if (subject !is null)
        {
            s ~= "; subject=<" ~ subject.toString() ~ ">";
        }
        if (escopo !is null)
        {
            s ~= " on " ~ escopo.toString();
        }
        return s;
    }
}

Erro toError(NowException ex)
{
    return new Erro(
        ex.classe,
        ex.msg,
        ex.escopo,
        ex.subject,
        ex,
        ex.code
    );
}
