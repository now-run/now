module now.commands.utils;

import now;

void iterateOverGenerators(
    Escopo escopo, Items generators, void delegate(Items) action
)
{
forLoop:
        foreach (generator; generators)
        {
            auto range = generator.range();

            while (true)
            {
                // Reminder: `nextOutput` will be
                // truncated on each call to `next`.
                auto nextOutput = new Output;
                auto nextExitCode = range.next(escopo, nextOutput);

                if (nextExitCode == ExitCode.Break)
                {
                    break forLoop;
                }
                else if (nextExitCode == ExitCode.Skip)
                {
                    continue;
                }
                action(nextOutput.items);
            }
        }
}

ExitCode executeAndOverwriteIfRelevant(
    SubProgram subprogram,
    Escopo escopo,
    Items input,
    Output output,
    ExitCode exitCode,
    ExitCode delegate() ifIsReturn = null,
    ExitCode delegate(ExitCode) orElse = null
)
{
        auto newExitCode = subprogram.run(escopo, input, output);
        if (newExitCode == ExitCode.Return)
        {
            if (ifIsReturn !is null)
            {
                return ifIsReturn();
            }
            else if (orElse !is null)
            {
                return orElse(newExitCode);
            }
        }

        if (newExitCode != ExitCode.Success)
        {
            return newExitCode;
        }
        else
        {
            return exitCode;
        }
}
