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
    List[string] dependsOn;
    Dict info;

    this(string name, Dict info)
    {
        this.name = name;
        this.parameters = info.getOrCreate!Dict("parameters");
        this.info = info;

        this.loadEventHandlers(info);
        this.loadDependsOn(info);
    }
    void loadEventHandlers(Dict info)
    {
        info.order.filter!(x => x[0..3] == "on.").each!((k) {
            auto v = cast(Dict)(info[k]);
            auto body = cast(String)v["body"];
            auto parser = new NowParser(body.toString());
            parser.line = this.info.documentLineNumber;
            this.eventHandlers[k] = parser.consumeSubProgram();
        });
    }
    void loadDependsOn(Dict info)
    {
        /*
        depends_on {
            pkg:installed {
                - git
                - make
            }
        }
        */
        auto depends_on = info.getOrCreate!Dict("depends_on");
        foreach (name, args; depends_on)
        {
            this.dependsOn[name] = cast(List)args;
        }
    }

    override string toString()
    {
        auto s = name;
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

    ExitCode run(string name, Input input, Output output, bool keepScope=false)
    {
        log("- run: ", this, " / ", input);
        // input: Escopo escopo, Items inputs, Args args, KwArgs kwargs

        // state!
        // TODO: evaluate each item after parameters evaluation
        // so user can reference them in the depends_on declaration.
        // Like this:
        // depends_on {
        //     directory {
        //         - $basedir
        //     }
        // }
        foreach (stateName, stateArgs; this.dependsOn)
        {
            input.escopo.document.states[stateName].run(stateArgs);
        }

        // Procedures are always top-level:
        Escopo newScope;
        if (keepScope)
        {
            newScope = input.escopo;
        }
        else
        {
            newScope = new Escopo(input.escopo.document, name, this);
        }

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
                defaultValue.properties["_default"] = new Boolean(true);
                newScope[parameterName] = defaultValue;
                log("-- from default values: newScope[", parameterName, "] = ", defaultValue);
                namedParametersAlreadySet ~= parameterName;
                setParametersCount++;
            }
        }

        // Named arguments:
        log("- Named arguments");
        foreach (key, value; input.kwargs)
        {
            value.properties["_default"] = new Boolean(false);
            newScope[key] = value;
            log("-- from kwargs: newScope[", key, "] = ", value);
            if (!namedParametersAlreadySet.canFind(key))
            {
                namedParametersAlreadySet ~= key;
                setParametersCount++;
            }
        }

        // Now iterate positional parameters to
        // find correspondent arguments
        log("-- named arguments already set: ", namedParametersAlreadySet);
        log("- Positional arguments");
        /*
        Positional parameters always overwrite whatever came first.
        > cmd a b c -- (first = 1) (second = 2) (third = 3)
        will end up having
            first = a
            second = b
            third = c
        */
        size_t lastIndex = -1;
        foreach (index, argument; input.args.take(parameters.order.length))
        {
            auto defaultRef = ("_default" in argument.properties);
            if (defaultRef is null)
            {
                argument.properties["_default"] = new Boolean(false);
            }
            auto key = parameters.order[index];
            newScope[key] = argument;
            log("-- from args: newScope[", key, "] = ", argument);
            setParametersCount++;
            lastIndex = index;
        }

        auto remainingParameters = parameters.order.length - setParametersCount;
        foreach (index, argument; input.inputs.take(remainingParameters))
        {
            // parameters.length = 4
            // arguments = 2
            // lastIndex = 1
            // nextIndex should be 2
            // nextIndex = lastIndex (1) + index (0) + 1
            auto defaultRef = ("_default" in argument.properties);
            if (defaultRef is null)
            {
                argument.properties["_default"] = new Boolean(false);
            }
            auto key = parameters.order[lastIndex + index + 1];
            newScope[key] = argument;
            log("-- from inputs: newScope[", key, "] = ", argument);
            setParametersCount++;
            input.inputs.popFront;
        }

        if (setParametersCount < parameters.order.length)
        {
            // Try getting arguments from input.inputs:

            throw new InvalidArgumentsException(
                input.escopo,
                "Not enough arguments for `" ~ name
                ~ "`. It should be at least " ~ parameters.order.length.to!string
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
        exitCode = this.handleEvent("call", newScope, output);
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
            try
            {
                exitCode = this.doRun(name, input, output);
            }
            catch (NowException ex)
            {
                if (input.escopo.rootCommand !is null)
                {
                    auto rootCommand = input.escopo.rootCommand;
                    auto errorHandler = rootCommand.getEventHandler("error");
                    if (errorHandler !is null)
                    {
                        auto errorScope = newScope.addPathEntry("on.error");
                        errorScope.rootCommand = null;
                        errorScope["error"] = ex.toError();
                        return rootCommand.handleEvent("error", errorScope, output);
                    }
                }
                // else:
                throw ex;
            }
        }

        // on.return
        auto onReturnExitCode = this.handleEvent("return", newScope, output);

        /*
        No base_command can return a ExitCode.Return!
        */
        if (onReturnExitCode == ExitCode.Return)
        {
            return ExitCode.Success;
        }
        else if (exitCode == ExitCode.Return)
        {
            return ExitCode.Success;
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

    SubProgram getEventHandler(string eventName)
    {
        auto fullname = "on." ~ eventName;
        if (auto handlerPtr = (fullname in eventHandlers))
        {
            return *handlerPtr;
        }
        else
        {
            return null;
        }
    }

    ExitCode handleEvent(string eventName, Escopo escopo, Output output)
    {
        log("- handleEvent: ", eventName);
        auto handler = getEventHandler(eventName);
        if (handler !is null)
        {
            Items input = output.items;
            output.items.length = 0;
            /*
            Event handlers are not procedures or
            commands, but simple SubPrograms.
            */
            return handler.run(escopo, input, output);
        }
        else
        {
            return ExitCode.Success;
        }
    }
}
