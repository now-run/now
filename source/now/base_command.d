module now.base_command;


import std.algorithm : canFind;

import now.exceptions;
import now.nodes;
import now.grammar;


class BaseCommand
{
    SubProgram[string] eventHandlers;

    string name;
    Dict parameters;
    Dict info;
    Item workdir;

    this(string name, Dict info)
    {
        this.name = name;
        this.parameters = info.getOrCreate!Dict("parameters");
        this.info = info;

        // event handlers:
        info.order.filter!(x => x[0..3] == "on.").each!((k) {
            auto v = cast(Dict)(info[k]);
            auto body = cast(String)v["body"];
            auto parser = new NowParser(body.toString());
            this.eventHandlers[k] = parser.consumeSubProgram();
        });

        this.workdir = info.getOrNull("workdir");
    }

    Context run(string name, Context context)
    {
        debug {stderr.writeln(">>> running:", name);}
        auto newScope = new Escopo(context.escopo);
        // Procedures are always top-level:
        newScope.parent = null;
        newScope.rootCommand = this;
        newScope.description = name;

        string[] parametersAlreadySet;

        // Set every default value in the parameters:
        foreach (parameterName, info; parameters.values)
        {
            Item *defaultValuePtr = ("default" in (cast(Dict)info).values);
            if (defaultValuePtr !is null)
            {
                auto defaultValue = *defaultValuePtr;
                newScope[parameterName] = defaultValue;
                debug {
                    stderr.writeln(parameterName, "(default) = ", defaultValue);
                }
                parametersAlreadySet ~= parameterName;
            }
        }

        /*
        Everything is an argument, including the piped input.
        But after parsing all of then, if the input was not
        used as argument for this, then it must be restored
        so inner commands can read from it.
        */
        auto arguments = context.items;
        auto inputSize = context.inputSize;
        debug {stderr.writeln("arguments:", arguments);}

        string[] namedParametersAlreadySet;
        Items positionalArguments;

        // Search for named arguments:
        bool lookForNamedArguments = true;
        foreach (argument; arguments)
        {
            debug {
                stderr.writeln(" argument:", argument, "/", argument.type);
            }
            if (argument.toString() == "--")
            {
                lookForNamedArguments = false;
                continue;
            }

            if (lookForNamedArguments && argument.type == ObjectType.Pair)
            {
                List pair = cast(List)argument;
                auto key = pair.items[0].toString();
                auto value = pair.items[1];
                newScope[key] = value;
                debug {stderr.writeln(key, "=", value);}
                namedParametersAlreadySet ~= key;
                parametersAlreadySet ~= key;
            }
            else
            {
                positionalArguments ~= argument;
            }
        }

        debug {
            stderr.writeln("positionalArguments:", positionalArguments);
            stderr.writeln("namedParametersAlreadySet:", namedParametersAlreadySet);
        }

        // Now iterate positional parameters to
        // find correspondent arguments
        int currentIndex = 0;
        foreach (parameterName; parameters.order)
        {
            if (namedParametersAlreadySet.canFind(parameterName))
            {
                continue;
            }

            else if (currentIndex >= positionalArguments.length)
            {
                if (parametersAlreadySet.canFind(parameterName))
                {
                    continue;
                }
                else
                {
                    auto msg = "Not enough arguments passed to command"
                        ~ " `" ~ name ~ "`.";
                    return context.error(msg, ErrorCode.InvalidSyntax, "");
                }
            }
            auto argument = positionalArguments[currentIndex++];
            newScope[parameterName] = argument;
            debug {
                stderr.writeln(parameterName, "=", argument);
            }
        }

        auto newContext = context.next(newScope, context.size);

        debug {
            stderr.writeln("xxx newContext.size: ", newContext.size);
            stderr.writeln("xxx newContext.inputSize: ", newContext.inputSize);
        }

        // Unused arguments go to this "va_list" crude implementation.
        // Inputs will be pushed back, absent from `args`.
        auto remaining = positionalArguments[currentIndex..$];
        auto inputsPushedBack = 0;
        foreach (unusedArg; remaining.retro)
        {
            if (inputsPushedBack >= inputSize)
            {
                break;
            }
            debug {stderr.writeln("pushing input back:", unusedArg);}
            newContext.push(unusedArg);
            inputsPushedBack++;
        }
        newContext.inputSize = inputsPushedBack;
        auto argsLength = remaining.length - inputsPushedBack;
        debug {
            stderr.writeln("remaining:", remaining);
            stderr.writeln("inputsPushedBack:", inputsPushedBack);
        }
        if (argsLength > 0)
        {
            newScope["args"] = remaining[0..argsLength];
        }
        else
        {
            newScope["args"] = [];
        }

        debug {
            stderr.writeln(" extra args: ", newScope["args"]);
        }

        // TODO: what was this supposed to do, exactly?
        // See lines 152-176!
        // newContext.push(positionalArguments[$-inputSize..$]);
        // 2023-03-22: it seems we really don't need it.

        // RUN!
        // pre-run
        newContext = this.preRun(name, newContext);
        if (newContext.exitCode == ExitCode.Failure)
        {
            return newContext;
        }
        debug {
            stderr.writeln("xxx after preRun newContext.size: ", newContext.size);
        }

        // on.call
        newContext = this.handleEvent(newContext, "call");
        if (newContext.exitCode == ExitCode.Failure)
        {
            return newContext;
        }
        else if (newContext.exitCode == ExitCode.Skip)
        {
            // do not execute the handler
            // but execute on.return
        }
        else if (newContext.exitCode == ExitCode.Break)
        {
            // do not execute anything else
            context.exitCode = ExitCode.Break;
            // XXX: should we set the exitCode to Success???
            return context;
        }
        else
        {
            // run
            newContext = this.doRun(name, newContext);
        }
        if (newContext.exitCode == ExitCode.Failure)
        {
            return newContext;
        }
        debug {
            stderr.writeln("xxx   doRun.context.size: ", newContext.size);
            stderr.writeln("xxx   doRun.context.inputSize: ", newContext.inputSize);
        }

        // on.return
        newContext = this.handleEvent(newContext, "return");
        if (newContext.exitCode == ExitCode.Failure)
        {
            return newContext;
        }
        // -----------------------------------

        context.size = newContext.size;
        debug {
            stderr.writeln("xxx exiting.");
            stderr.writeln("xxx   context.size: ", context.size);
            stderr.writeln("xxx   context.exitCode: ", context.exitCode);
        }

        if (newContext.exitCode == ExitCode.Return)
        {
            context.exitCode = ExitCode.Success;
        }
        else
        {
            context.exitCode = newContext.exitCode;
        }

        return context;
    }
    Context preRun(string name, Context context)
    {
        // pass
        return context;
    }
    Context doRun(string name, Context context)
    {
        // pass
        return context;
    }

    Context handleEvent(Context context, string event)
    {
        debug {
            stderr.writeln("xxx handleEvent ", event, " for ", this.name);
            stderr.writeln("xxx     context.size: ", context.size);
            stderr.writeln("xxx     context.inputSize: ", context.inputSize);
        }
        auto fullname = "on." ~ event;
        if (auto handlerPtr = (fullname in eventHandlers))
        {
            auto handler = *handlerPtr;
            debug {stderr.writeln("Calling ", fullname);}

            /*
            Event handlers are not procedures or
            commands, but simple SubProgram.
            */

            Escopo newScope = context.escopo;

            if (event == "error")
            {
                newScope = new Escopo(context.escopo);
                // Avoid calling on.error recursively:
                newScope.rootCommand = null;
                // We still want to share variables:
                newScope.variables = context.escopo.variables;

                if (context.peek().type == ObjectType.Error)
                {
                    newScope["error"] = context.pop();
                }
            }

            // auto newContext = Context(context.process, newScope);
            auto newContext = context.next(newScope);

            newContext = context.process.run(handler, newContext);
            debug {stderr.writeln(" returned context:", newContext);}
            return newContext;
        }
        else
        {
            debug {
                stderr.writeln("proc ", name, " has no ", event, " handler.");
            }
            return context;
        }
    }
}
