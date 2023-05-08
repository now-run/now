module now.exceptions;


import now.escopo;
import now.nodes;


template customException(string name)
{
    const string customException = "
class " ~ name ~ " : Exception
{
    this(string msg)
    {
        super(msg);
    }
}
    ";
}


class NowException : Exception
{
    int code;
    Item subject;
    string typename;
    Escopo escopo;

    this(Escopo escopo, string msg, int code=-1, Item subject=null)
    {
        super(msg);
        this.escopo = escopo;
        this.code = code;
        this.subject = subject;
    }
}

template customNowException(string name)
{
    const string customNowException = "
class " ~ name ~ " : NowException
{
    this(Escopo escopo, string msg, int code=-1, Item subject=null)
    {
        super(escopo, msg, code, subject);
        this.typename = \"" ~ name ~ "\";
    }
}
    ";
}

mixin(customNowException!"EmptyException");
mixin(customNowException!"HTTPException");
mixin(customNowException!"IncompleteInputException");
mixin(customNowException!"InvalidArgumentsException");
mixin(customNowException!"InvalidConfigurationException");
mixin(customNowException!"InvalidException");
mixin(customNowException!"InvalidInputException");
mixin(customNowException!"IteratorException");
mixin(customNowException!"MethodNotFoundException");
mixin(customNowException!"NotFoundException");
mixin(customNowException!"NotImplementedException");
mixin(customNowException!"PathException");
mixin(customNowException!"ProcedureNotFoundException");
mixin(customNowException!"SyntaxErrorException");
mixin(customNowException!"SystemProcessException");
mixin(customNowException!"SystemProcessInputError");
mixin(customNowException!"UndefinedException");
mixin(customNowException!"UserException");
mixin(customNowException!"VariableNotFoundException");
// mixin(customNowException!"");
// mixin(customNowException!"");
// mixin(customNowException!"");
