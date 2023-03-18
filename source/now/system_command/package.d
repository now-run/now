module now.system_command;

import std.process;
import std.stdio : readln;
import std.string;

import now.nodes;


CommandsMap systemProcessCommands;


class SystemCommand : BaseCommand
{
    string[] which;
    List command;

    this(string name, Dict info)
    {
        super(name, info);

        /*
        [system_commands/list-dir]
        parameters {
            path {
                type string
                default ""
            }
        }
        workdir "/opt"
        which "ls -h"
        command "ls"
        */
        info.on("which", delegate (item) {
            auto cmd = item.toString().split(" ");
            // TODO: run which value to check if the
            // requested command is available.
        }, delegate () {
            // TODO: run `which` (the system command) to
            // check if the requested command is available.
        });
        this.command = info.get!List(
            "command",
            delegate (d) {
                throw new Exception(
                    "commands/" ~ name
                    ~ " must declare a `command` value."
                );
                return cast(List)null;
            }
        );
        debug {
            stderr.writeln("SystemCommand ", name, " command: ", this.command);
        }
    }

    override Context doRun(string name, Context context)
    {
        Item inputStream;
        string[] arguments;

        // We need this because we support event handling:
        context.escopo.rootCommand = this;

        if (context.inputSize == 1)
        {
            arguments = context.pop(context.size - 1).map!(x => to!string(x)).array;
            inputStream = context.pop();
        }
        else if (context.inputSize > 1)
        {
            auto msg = name ~ ": cannot handle multiple inputs";
            return context.error(msg, ErrorCode.InvalidInput, "");
        }
        else
        {
            arguments = context.items.map!(x => to!string(x)).array;
        }

        debug {
            stderr.writeln(" >> arguments: ", arguments);
        }

        /*
        command {
            - "ls"
            - $options
            - $path
        }
        We must evaluate that before and running.
        */
        Items cmdItems;
        foreach (segment; command.items)
        {
            context = segment.evaluate(context);
            Item nextItem = context.pop();
            if (nextItem.type == ObjectType.List)
            {
                // Expand Lists inside the command arguments:
                cmdItems ~= (cast(List)nextItem).items;
            }
            // dict (verbosity = 3)
            // -> "--verbosity=3"
            else if (nextItem.type == ObjectType.Dict)
            {
                foreach (k, v; (cast(Dict)nextItem).values)
                {
                    cmdItems ~= new String(k ~ "=" ~ v.toString());
                }
            }
            else
            {
                cmdItems ~= nextItem;
            }
        }
        List cmd = new List(cmdItems);

        // set each variable on this Escopo as
        // a environment variable:
        string[string] env;
        foreach (key, value; context.escopo.variables)
        {
            // TODO:
            // set x 1 2 3
            // env["x"] = ?
            debug {
                stderr.writeln( this.name, " ", key, "=", value);
            }
            if (value.length)
            {
                env[key] = value[0].toString();
            }
            else
            {
                env[key] = "";
            }
        }

        try
        {
            context.push(
                new SystemProcess(cmd, arguments, inputStream, env)
            );
        }
        catch (ProcessException ex)
        {
            return context.error(ex.msg, ErrorCode.Unknown, "");
        }
        return context;
    }
}


class SystemProcess : Item
{
    ProcessPipes pipes;
    std.process.Pid pid;
    Item inputStream;
    List command;
    string[] arguments;
    string[] cmdline;
    int returnCode = 0;
    bool _isRunning;
    string[string] env;

    this(
        List command,
        string[] arguments,
        Item inputStream=null,
        string[string] env=null
    )
    {
        this.type = ObjectType.SystemProcess;
        this.typeName = "system_process";
        this.commands = systemProcessCommands;

        this.command = command;
        this.env = env;
        debug {stderr.writeln("this.command:", this.command);}
        this.arguments = arguments;
        this.inputStream = inputStream;

        this.cmdline ~= command.items.map!(x => x.toString()).array;
        this.cmdline ~= arguments;

        debug {stderr.writeln("cmdline:", cmdline);}

        if (inputStream is null)
        {
            pipes = pipeProcess(
                cmdline,
                Redirect.stdout | Redirect.stderr,
                this.env
            );
        }
        else
        {
            pipes = pipeProcess(
                cmdline,
                Redirect.all,
                this.env
            );
        }

        this.pid = pipes.pid;
    }

    override string toString()
    {
        return this.cmdline.join(" ");
    }

    bool isRunning()
    {
        if (_isRunning)
        {
            _isRunning = !this.pid.tryWait().terminated;
        }
        return _isRunning;
    }

    override Context next(Context context)
    {
        // For the output:
        string line = null;

        while (true)
        {
            // Send from inputStream, first:
            if (inputStream !is null)
            {
                auto inputContext = this.inputStream.next(context);
                if (inputContext.exitCode == ExitCode.Break)
                {
                    this.inputStream = null;
                    pipes.stdin.close();
                    continue;
                }
                else if (inputContext.exitCode == ExitCode.Skip)
                {
                    continue;
                }
                else if (inputContext.exitCode != ExitCode.Continue)
                {
                    auto msg = "Error while reading from " ~ this.toString();
                    return context.error(msg, returnCode, "");
                }

                foreach (item; inputContext.items)
                {
                    string s = item.toString();
                    pipes.stdin.writeln(s);
                    pipes.stdin.flush();
                }
                continue;
            }

            if (pipes.stdout.eof)
            {
                if (isRunning)
                {
                    context.exitCode = ExitCode.Skip;
                    return context;
                }

                wait();
                _isRunning = false;

                if (returnCode != 0)
                {
                    auto msg = "Error while executing " ~ this.toString();
                    return context.error(msg, returnCode, "", this);
                }
                else
                {
                    context.exitCode = ExitCode.Break;
                    return context;
                }
            }

            line = pipes.stdout.readln();

            if (line is null)
            {
                context.exitCode = ExitCode.Skip;
                return context;
            }
            else
            {
                break;
            }
        }

        context.push(line.stripRight("\n"));
        context.exitCode = ExitCode.Continue;
        return context;
    }
    void wait()
    {
        returnCode = pid.wait();
    }
}

class SystemProcessError : Item
{
    SystemProcess parent;
    ProcessPipes pipes;
    this(SystemProcess parent)
    {
        this.parent = parent;
        this.pipes = parent.pipes;
        this.type = ObjectType.SystemProcessError;
        this.typeName = "system_process_error";
    }

    override string toString()
    {
        return "error stream for " ~ this.parent.toString();
    }

    override Context next(Context context)
    {
        // For the output:
        string line = null;

        while (true)
        {
            if (!pipes.stderr.eof)
            {
                line = pipes.stderr.readln();
                if (line is null)
                {
                    context.exitCode = ExitCode.Skip;
                    return context;
                }
                else
                {
                    break;
                }
            }
            else 
            {
                context.exitCode = ExitCode.Break;
                return context;
            }
        }

        context.push(line.stripRight("\n"));
        context.exitCode = ExitCode.Continue;
        return context;
    }
}
