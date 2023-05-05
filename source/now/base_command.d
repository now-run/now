module now.base_command;


import std.algorithm : canFind;
import std.range : take;

import now;
import now.exceptions;


class BaseCommand
{
    SubProgram[string] eventHandlers;

    string name;
    Dict parameters;
    Dict info;
    String workdir;

    this(string name, Dict info)
    {
        this.name = name;
        this.parameters = info.getOrCreate!Dict("parameters");
        this.info = info;

        // event handlers:
        this.loadEventHandlers(info);

        this.workdir = info.get!String("workdir", null);
    }
    void loadEventHandlers(Dict info)
    {
        info.order.filter!(x => x[0..3] == "on.").each!((k) {
            auto v = cast(Dict)(info[k]);
            auto body = cast(String)v["body"];
            auto parser = new NowParser(body.toString());
            this.eventHandlers[k] = parser.consumeSubProgram();
        });
    }

    override string toString()
    {
        auto s = name ~ "  ";
        string[] keys;
        foreach (key, value; parameters)
        {
            auto dict = cast(Dict)value;
            auto defaultValue = dict.get("default", null);
            if (defaultValue !is null)
            {
                keys ~= key ~ "=" ~ defaultValue.toString();
            }
            else
            {
                keys ~= key;
            }
        }
        return s ~ "  " ~ keys.join(" ");
    }

    ExitCode run(string name, Input input, Output output)
    {
        log("- run: ", this, " / ", input);
        // input: Escopo escopo, Items inputs, Args args, KwArgs kwargs

        // Procedures are always top-level:
        auto newScope = input.escopo.createChild(name);
        newScope.parent = null;

        auto setParametersCount = 0;
        string[] namedParametersAlreadySet;

        // Set every default value in the parameters:
        log("- Default parameters values");
        foreach (parameterName, info; parameters)
        {
            auto parameterDict = cast(Dict)info;
            auto defaultValue = parameterDict.get("default", null);
            if (defaultValue !is null)
            {
                newScope[parameterName] = defaultValue;
                namedParametersAlreadySet ~= parameterName;
                setParametersCount++;
            }
        }

        // Named arguments:
        log("- Named arguments");
        foreach (key, value; input.kwargs)
        {
            newScope[key] = value;
            if (!namedParametersAlreadySet.canFind(key))
            {
                namedParametersAlreadySet ~= key;
                setParametersCount++;
            }
        }

        // Now iterate positional parameters to
        // find correspondent arguments
        log("-- named arguments set: ", namedParametersAlreadySet);
        log("- Positional arguments");
        /*
        Positional parameters always overwrite whatever came first.
        > cmd a b c -- (first = 1) (second = 2) (third = 3)
        will end up having
            first = a
            second = b
            third = c
        */
        foreach (index, argument; input.args.take(parameters.order.length))
        {
            auto key = parameters.order[index];
            newScope[key] = argument;
            setParametersCount++;
        }

        if (setParametersCount < parameters.order.length)
        {
            throw new InvalidArgumentsException(
                input.escopo,
                "Not enough arguments for " ~ name
                ~ ". It should be at least " ~ parameters.order.length.to!string
                ~ " but only " ~ setParametersCount.to!string ~ " were found."
            );
        }

        // Unused arguments go to the $args variable (List)
        if (input.args.length > parameters.order.length)
        {
            newScope["args"] = new List(input.args[parameters.order.length..$]);
        }
        else
        {
            newScope["args"] = new List([]);
        }

        // Inputs go to the $inputs variable (List)
        newScope["inputs"] = new List(input.inputs);

        // Since we're not going to use the old scope anymore:
        input.escopo = newScope;

        // -------------------------
        // Finally, RUN!
        // pre-run
        log("- preRun");
        auto exitCode = this.preRun(name, input, output);
        if (exitCode != ExitCode.Success)
        {
            return exitCode;
        }

        // on.call
        exitCode = this.handleEvent("call", input, output);
        if (exitCode == ExitCode.Skip)
        {
            // do not execute the handler
            // but execute on.return
        }
        else if (exitCode == ExitCode.Break)
        {
            // do not execute anything else
            // XXX: should we set the exitCode to Success???
            return exitCode;
        }
        else
        {
            // run
            log("- run");
            exitCode = this.doRun(name, input, output);
        }

        // on.return
        auto onReturnExitCode = this.handleEvent("return", input, output);

        // TODO: check if this make sense:
        if (onReturnExitCode == ExitCode.Return)
        {
            return onReturnExitCode;
        }
        else
        {
            return exitCode;
        }
    }
    ExitCode preRun(string name, Input input, Output output)
    {
        // pass
        return ExitCode.Success;
    }
    ExitCode doRun(string name, Input input, Output output)
    {
        // pass
        return ExitCode.Success;
    }

    ExitCode handleEvent(string eventName, Input input, Output output)
    {
        log("- handleEvent: ", eventName);
        auto fullname = "on." ~ eventName;
        if (auto handlerPtr = (fullname in eventHandlers))
        {
            auto handler = *handlerPtr;

            /*
            Event handlers are not procedures or
            commands, but simple SubProgram.
            */

            if (eventName == "error")
            {
                // Avoid calling on.error recursively:
                auto newScope = input.escopo.createChild("on.error");
                newScope.rootCommand = null;
                return handler.run(newScope, output);
            }
            else
            {
                return handler.run(input.escopo, output);
            }
        }
        else
        {
            return ExitCode.Success;
        }
    }
}
