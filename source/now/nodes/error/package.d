module now.nodes.error;


import now;


MethodsMap errorMethods;


class Erro : Item
{
    int code = -1;
    string classe;
    string message;
    Item subject;
    Escopo escopo;
    NowException exception;

    this(string message, int code, string classe, Escopo escopo, Item subject=null, NowException ex=null)
    {
        this.message = message;
        this.code = code;
        this.classe = classe;
        this.escopo = escopo;
        this.subject = subject;

        this.type = ObjectType.Error;
        this.exception = ex;

        this.typeName = "error";
        this.methods = errorMethods;
    }

    // Conversions:
    override string toString()
    {
        string s = "Error " ~ to!string(code)
                   ~ ": " ~ message;
        if (classe)
        {
            s ~= " (" ~ classe ~ ")";
        }
        if (subject !is null)
        {
            s ~= " subject " ~ subject.toString();
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
        ex.msg,
        ex.code,
        ex.typename,
        ex.escopo,
        ex.subject,
        ex
    );
}
