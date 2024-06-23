module now.exceptions;


import now.escopo;
import now.nodes;


class NowException : Exception
{
    int code;
    Item subject;
    string classe;
    Escopo escopo;
    Pipeline pipeline;

    this(Escopo escopo, string msg, Item subject=null, int code=-1)
    {
        super(msg);
        this.escopo = escopo;
        this.subject = subject;
        this.code = code;
    }
}

template customNowException(string name)
{
    const string customNowException = "
class " ~ name ~ " : NowException
{
    this(Escopo escopo, string msg, int code)
    {
        super(escopo, msg, null, code);
        this.classe = \"" ~ name ~ "\";
    }
    this(Escopo escopo, string msg, int code, Item subject=null)
    {
        super(escopo, msg, subject, code);
        this.classe = \"" ~ name ~ "\";
    }
    this(Escopo escopo, string msg, Item subject=null, int code=-1)
    {
        super(escopo, msg, subject, code);
        this.classe = \"" ~ name ~ "\";
    }
}
    ";
}

mixin(customNowException!"AssertionError");
mixin(customNowException!"DException");
mixin(customNowException!"DError");
mixin(customNowException!"EmptyException");
mixin(customNowException!"HTTPException");
mixin(customNowException!"IncompleteInputException");
mixin(customNowException!"InvalidArgumentsException");
mixin(customNowException!"InvalidConfigurationException");
mixin(customNowException!"InvalidException");
mixin(customNowException!"InvalidInputException");
mixin(customNowException!"InvalidOperatorException");
mixin(customNowException!"InvalidPackageException");
mixin(customNowException!"IteratorException");
mixin(customNowException!"MethodNotFoundException");
mixin(customNowException!"NotFoundException");
mixin(customNowException!"NotImplementedException");
mixin(customNowException!"PathException");
mixin(customNowException!"ParsingErrorException");
mixin(customNowException!"ProcedureNotFoundException");
mixin(customNowException!"SyntaxErrorException");
mixin(customNowException!"SystemProcessException");
mixin(customNowException!"SystemProcessInputError");
mixin(customNowException!"TcpSocketException");
mixin(customNowException!"UndefinedException");
mixin(customNowException!"UserException");
mixin(customNowException!"VariableNotFoundException");
// mixin(customNowException!"");
// mixin(customNowException!"");
// mixin(customNowException!"");



ExitCode errorHandler(Escopo escopo, Pipeline pipeline, ExitCode delegate() f)
{
    try
    {
        return f();
    }
    catch (NowException ex)
    {
        log("escopo.errorHandler NowException: ", ex);
        throw ex;
    }
    catch (Exception ex)
    {
        log("escopo.errorHandler Exception: ", ex);
        auto ex2 = new DException(
            escopo,
            ex.msg,
        );
        ex2.pipeline = pipeline;
        log(" -> ", ex2);
        throw ex2;
    }
    catch (object.Error ex)
    {
        log("escopo.errorHandler object.Error: ", ex);
        if (pipeline !is null)
        {
            stderr.writeln("p> ", pipeline);
            if (pipeline.documentLineNumber)
            {
                stderr.writeln("l> ", pipeline.documentLineNumber);
            }
        }
        stderr.writeln(
            "This is an internal error, your program may not be wrong."
        );
        stderr.writeln(
            "===== Error ====="
        );
        stderr.writeln(ex);

        auto ex2 = new DError(
            null,
            ex.msg,
        );
        ex2.pipeline = pipeline;
        throw ex2;
    }
}

ExitCode errorPrinter(ExitCode delegate() f)
{
    try
    {
        return f();
    }
    catch (NowException ex)
    {
        stderr.writeln("c> ", ex.classe);
        stderr.writeln("s> ", ex.escopo);
        stderr.writeln("m> ", ex.msg);
        if (ex.pipeline !is null)
        {
            stderr.writeln("p> ", ex.pipeline);
            if (ex.pipeline.documentLineNumber)
            {
                stderr.writeln("l> ", ex.pipeline.documentLineNumber);
            }
        }
        throw ex;
    }
}
