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
        this.subject = subject;
        this.message = message;
        this.code = code;
        this.classe = classe;
        this.type = ObjectType.Error;
        this.escopo = escopo;
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
        s ~= " on " ~ escopo.toString();
        return s;
    }
}

Erro toError(NowException ex)
{
    return new Erro(
        ex.msg,
        ex.code,
        "NowException",
        ex.escopo,
        ex.subject,
        ex
    );
}
