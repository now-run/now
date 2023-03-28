module now.nodes.subprogram.commands;

import now.nodes;


static this()
{
    subprogramCommands["run"] = function (string path, Context context)
    {
        /*
        > run { print 123 }
        123

        Specially useful in conjunction with `when`:
        > set x 1
        > run {
              when ($x == 0) {zero}
              when ($x == 1) {one}
              default {other}
          } | print
        one
        */
        auto body = context.pop!SubProgram();
        auto escopo = new Escopo(context.escopo);

        auto returnedContext = context.process.run(
            body, context.next(escopo, 0)
        );
        debug {stderr.writeln("returnedContext.size:", returnedContext.size);}

        context.size = returnedContext.size;
        if (returnedContext.exitCode == ExitCode.Return)
        {
            // Contain the return chain reaction:
            context.exitCode = ExitCode.Success;
        }
        else
        {
            context.exitCode = returnedContext.exitCode;
        }

        return context;
    };
}
