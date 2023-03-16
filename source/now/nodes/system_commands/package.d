module now.nodes.system_commands;

import std.process;
import std.stdio : readln;
import std.string;

import now.nodes;


CommandsMap systemProcessCommands;


class SystemCommandCall : Procedure
{
    Dict parameters;
    string[] which;
    SectionDict command;
    Item workdir;

    this(string name, SectionDict command, Dict info)
    {
        auto parameters = info.getOrCreate!Dict("parameters");
        super(name, parameters, null);

        // this.info = info;
        this.workdir = info.getOrNull("workdir");
        this.command = command;
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
        We must evaluate that before splitting and running.
        */

        context = this.command.evaluateAsList(context);
        List cmd = context.pop!List();

        try
        {
            context.push(
                new SystemProcess(cmd, arguments, inputStream)
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

    auto type = ObjectType.SystemProcess;
    auto typeName = "system_process";

    this(List command, string[] arguments, Item inputStream=null)
    {
        // TODO: split with regexp or something safer than simply `split`:
        this.command = command;
        debug {stderr.writeln("this.command:", this.command);}
        this.arguments = arguments;
        this.inputStream = inputStream;

        this.cmdline ~= command.items.map!(x => x.toString()).array;
        this.cmdline ~= arguments;

        debug {stderr.writeln("cmdline:", cmdline);}

        if (inputStream is null)
        {
            pipes = pipeProcess(cmdline, Redirect.stdout | Redirect.stderr);
        }
        else
        {
            pipes = pipeProcess(cmdline, Redirect.all);
        }

        this.pid = pipes.pid;
        this.commands = systemProcessCommands;
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
        this.type = ObjectType.Other;
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
