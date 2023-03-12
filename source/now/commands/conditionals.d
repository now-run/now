import commands;
import nodes;


// Commands:
static this()
{
    commands["if"] = function (string path, Context context)
    {
        auto isConditionTrue = context.pop!bool();
        auto thenBody = context.pop!SubProgram();

        if (isConditionTrue)
        {
            // Consume eventual "else":
            context.items();
            // Run body:
            context = context.process.run(thenBody, context.next());
        }
        // When there's no else clause:
        else if (context.size == 0)
        {
            context.exitCode = ExitCode.Success;
        }
        // else {...}
        // else if {...}
        else
        {
            auto elseWord = context.pop!string();
            if (elseWord != "else" || context.size != 1)
            {
                auto msg = "Invalid format for if/then/else clause:"
                           ~ " elseWord found was " ~ elseWord  ~ ".";
                return context.error(msg, ErrorCode.InvalidSyntax, "");
            }

            auto elseBody = context.pop!SubProgram();
            context = context.process.run(elseBody, context.next());
        }

        return context;
    };

    commands["when"] = function (string path, Context context)
    {
        /*
        If first argument is true, executes the second one and return.
        */
        auto isConditionTrue = context.pop!bool();
        auto thenBody = context.pop!SubProgram();

        if (isConditionTrue)
        {
            context = context.process.run(thenBody, context.next());
            debug {stderr.writeln("when>returnedContext.size:", context.size);}

            // Whatever the exitCode was (except Failure), we're going
            // to force a return:
            if (context.exitCode != ExitCode.Failure)
            {
                context.exitCode = ExitCode.Return;
            }
        }

        return context;
    };
    commands["default"] = function (string path, Context context)
    {
        /*
        Just like when, but there's no "first argument" to evaluate,
        it always executes the body and returns.
        */
        auto body = context.pop!SubProgram();

        context = context.process.run(body, context.next());

        // Whatever the exitCode was (except Failure), we're going
        // to force a return:
        if (context.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.Return;
        }

        return context;
    };
}
