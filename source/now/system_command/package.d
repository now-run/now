module now.system_command;

import std.process;
import std.stdio : readln;
// import std.string;
import std.algorithm.mutation : stripRight;

import now.nodes;


CommandsMap systemProcessCommands;


class SystemCommand : BaseCommand
{
    string[] which;
    List command;
    string optionPrefix;
    string keyValueSeparator;
    Item workdir;

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

        try
        {
            auto c = info["command"];
        }
        catch (Exception ex)
        {
            // do nothing
        }

        auto cmdItem = info.get(
            "command",
            delegate (d) {
                throw new Exception(
                    "commands/" ~ name
                    ~ " must declare a `command` value."
                );
                return cast(Item)null;
            }
        );
        if (cmdItem.type == ObjectType.List)
        {
            this.command = cast(List)cmdItem;
        }
        else if (cmdItem.type == ObjectType.Dict)
        {
            this.command = (cast(Dict)cmdItem).asList();
        }
        else
        {
            throw new Exception(
                "commands/" ~ name
                ~ ".command must be a list"
            );
        }

        /*
        Option prefix and key/value separator follows
        GNU conventions by default ("--key=value").
        */
        this.optionPrefix = info.get!String(
            "option_prefix",
            delegate (Dict d) {
                auto prefix = new String("--");
                d["option_prefix"] = prefix;
                return prefix;
            }
        ).toString();
        this.keyValueSeparator = info.get!String(
            "key_value_separator",
            delegate (Dict d) {
                auto separator = new String("=");
                d["key_value_separator"] = separator;
                return separator;
            }
        ).toString();

        this.workdir = info.get!Item(
            "workdir",
            delegate (Dict d) {
                return cast(Item)null;
            }
        );
    }

    override Context doRun(string name, Context context)
    {
        Item inputStream;
        string[] arguments;

        // We need this because we support event handling:
        context.escopo.rootCommand = this;

        debug {
            stderr.writeln("xxx SystemCommand ", name);
            stderr.writeln("xxx   context.inputSize: ", context.inputSize);
        }
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
            stderr.writeln("xxx   arguments: ", arguments);
            stderr.writeln("xxx   command: ", command);
            stderr.writeln("xxx   inputStream: ", inputStream);
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
                    cmdItems ~= new String(
                        this.optionPrefix
                        ~ k
                        ~ this.keyValueSeparator
                        ~ v.toString()
                    );
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
            debug {stderr.writeln(this.name, " ", key, "=", value);}
            if (value.length)
            {
                env[key] = value[0].toString();
            }
            else
            {
                env[key] = "";
            }
        }

        // Evaluate workdir:
        string workdirStr = null;
        if (workdir !is null)
        {
            context = workdir.evaluate(context);
            workdirStr = context.pop().toString();
        }

        try
        {
            context.push(
                new SystemProcess(cmd, arguments, inputStream, env, workdirStr)
            );
        }
        catch (ProcessException ex)
        {
            return context.error(ex.msg, ErrorCode.Unknown, "");
        }
        debug {
            stderr.writeln("SystemProcess.doRun.context.size:", context.size);
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
        string[string] env=null,
        string workdir=null
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
                Redirect.stdout,
                this.env,
                Config(),
                workdir
            );
        }
        else
        {
            pipes = pipeProcess(
                cmdline,
                Redirect.stdin | Redirect.stdout,
                this.env,
                Config(),
                workdir
            );
        }

        this.pid = pipes.pid;
    }

    override string toString()
    {
        auto s = this.cmdline.join(" ");
        if (s.length > 64)
        {
            return s[0..64] ~ "...";
        }
        else
        {
            return s;
        }
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
                debug {stderr.writeln("xxx ", this.command.items[0], " inputStream is not null");}
                auto inputContext = this.inputStream.next(context);
                if (inputContext.exitCode == ExitCode.Break)
                {
                    debug {stderr.writeln("xxx ", this.command.items[0], " inputContext -> Break");}
                    this.inputStream = null;
                    pipes.stdin.close();
                    continue;
                }
                else if (inputContext.exitCode == ExitCode.Skip)
                {
                    debug {stderr.writeln("xxx ", this.command.items[0], " inputContext -> Skip");}
                    continue;
                }
                else if (inputContext.exitCode != ExitCode.Continue)
                {
                    return context.error(
                        "Error on " ~ this.toString()
                        ~ " while reading from "
                        ~ inputStream.toString()
                        ~ " (exitCode " ~ inputContext.exitCode.to!string ~ ")",
                        returnCode,
                        "",
                        inputStream
                    );
                }

                foreach (item; inputContext.items)
                {
                    string s = item.toString();
                    debug {
                        stderr.writeln("xxx ", this.command.items[0], " writing <", s, "> to pipes.stdin");
                    }
                    pipes.stdin.writeln(s);
                    pipes.stdin.flush();
                }
                continue;
            }
            else
            {
                debug {stderr.writeln("xxx ", this.command.items[0], " inputStream is null");}
            }

            if (pipes.stdout.eof)
            {
                debug {stderr.writeln("xxx ", this.command.items[0], " stdout.eof");}
                if (isRunning)
                {
                    debug {stderr.writeln("xxx ", this.command.items[0], " isRunning. Returning Skip");}
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
                    debug {
                        stderr.writeln("xxx ", this.command.items[0], " returnCode is zero. Returning Break");
                    }
                    context.exitCode = ExitCode.Break;
                    return context;
                }
            }

            line = pipes.stdout.readln();
            debug {stderr.writeln("xxx ", this.command.items[0], " line=", line);}

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

        context.push(line.stripRight('\n'));
        context.exitCode = ExitCode.Continue;
        debug {stderr.writeln("xxx ", this.command.items[0], " returning Continue");}
        return context;
    }
    void wait()
    {
        returnCode = pid.wait();
    }
}
