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
        debug {
            stderr.writeln("BaseCommand:", name, info);
        }
        this.name = name;
        this.parameters = info.getOrCreate!Dict("parameters");
        this.info = info;

        // event handlers:
        info.order.filter!(x => x[0..3] == "on.").each!((k) {
            debug {
                stderr.writeln(" eventHandler:", k);
            }
            auto v = cast(Dict)(info[k]);
            auto body = cast(String)v["body"];
            auto parser = new Parser(body.toString());
            this.eventHandlers[k] = parser.consumeSubProgram();
        });

        this.workdir = info.getOrNull("workdir");
    }

    Context run(string name, Context context)
    {
        debug {
            stderr.writeln(">>> running:", name);
        }
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

        auto arguments = context.items;
        debug {
            stderr.writeln("arguments:", arguments);
        }

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

            if (lookForNamedArguments && argument.type == ObjectType.List)
            {
                List pair = cast(List)argument;
                if (pair.items.length != 2)
                {
                    return context.error(
                        "Invalid named parameter: "
                        ~ pair.toString(),
                        ErrorCode.InvalidSyntax,
                        ""
                    );
                }
                auto key = pair.items[0].toString();
                auto value = pair.items[1];
                newScope[key] = value;
                debug {
                    stderr.writeln(key, "=", value);
                }
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

            if (currentIndex >= positionalArguments.length)
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

        // Unused arguments go to this "va_list" crude implementation:
        newScope["args"] = arguments[currentIndex..$];
        debug {
            stderr.writeln(" extra args: ", newScope["args"]);
        }

        // RUN!
        newContext = this.doRun(name, newContext);
        newContext = context.process.closeCMs(newContext);

        if (newContext.exitCode == ExitCode.Failure)
        {
            return newContext;
        }

        context.size = newContext.size;

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
    Context doRun(string name, Context context)
    {
        // pass
        return context;
    }

    Context handleEvent(Context context, string event)
    {
        if (auto errorHandlerPtr = ("on.error" in eventHandlers))
        {
            auto errorHandler = *errorHandlerPtr;
            debug {
                stderr.writeln("Calling on.error");
                stderr.writeln(" context:", context);
            }
            /*
            Event handlers are not procedures or
            commands, but simple SubProgram.
            */
            auto newScope = new Escopo(context.escopo);
            // Avoid calling on.error recursively:
            newScope.rootCommand = null;
            auto newContext = Context(context.process, newScope);

            newContext = context.process.run(errorHandler, newContext);
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
