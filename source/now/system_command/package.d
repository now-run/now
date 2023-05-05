module now.system_command;


import std.algorithm.mutation : stripRight;
import std.process;
import std.stdio : readln;

import now;


MethodsMap systemProcessMethods;


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

        auto cmdItem = info.getOr(
            "command",
            delegate (d) {
                throw new Exception(
                    "commands/" ~ name
                    ~ " must declare a `command` value."
                );
                return cast(Item)null;
            }
        );
        switch (cmdItem.type)
        {
            case ObjectType.List:
                this.command = cast(List)cmdItem;
                break;
            case ObjectType.Dict:
                this.command = (cast(Dict)cmdItem).asList();
                break;
            default:
                throw new Exception(
                    "commands/" ~ name
                    ~ ".command must be a list"
                );
        }

        /*
        Option prefix and key/value separator follows
        GNU conventions by default ("--key=value").
        */
        this.optionPrefix = info.get!string("option_prefix", "--");
        this.keyValueSeparator = info.get!string("key_value_separator", "=");
        this.workdir = info.get("workdir", cast(Item)null);
    }

    override ExitCode doRun(string name, Input input, Output output)
    {
        Item inputStream;
        string[] arguments;

        // We need this because we support event handling:
        input.escopo.rootCommand = this;

        // Inputs:
        if (input.inputs.length == 1)
        {
            inputStream = input.inputs.front;
        }
        else if (input.inputs.length > 1)
        {
            throw new InvalidInputException(
                input.escopo,
                name ~ ": cannot handle multiple inputs",
            );
        }

        // Arguments:
        arguments = input.args.map!(x => to!string(x)).array;

        // TODO: handle kwargs!!!

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
            auto segmentOutput = segment.evaluate(input.escopo);
            // XXX: we PROBABLY have only one item, here:
            Item nextItem = segmentOutput.front;
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
        foreach (key, value; input.escopo)
        {
            // TODO:
            // set x 1 2 3
            // env["x"] = ?
            if (value.type == ObjectType.Sequence)
            {
                auto sequence = cast(Sequence)value;
                // XXX: should we try to emulate a bash array or something?
                env[key] = sequence.items.front.toString();
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
            auto workdirOutput = workdir.evaluate(input.escopo);
            workdirStr = workdirOutput.front.toString();
        }

        output.items ~= new SystemProcess(
            cmd, arguments, inputStream, env, workdirStr
        );
        return ExitCode.Success;
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
        this.methods = systemProcessMethods;

        this.command = command;
        this.env = env;
        this.arguments = arguments;
        this.inputStream = inputStream;

        this.cmdline ~= command.items.map!(x => x.toString()).array;
        this.cmdline ~= arguments;

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

    override ExitCode next(Escopo escopo, Output output)
    {
        // For the output:
        string line = null;

        while (true)
        {
            // Send from inputStream, first:
            if (inputStream !is null)
            {
                auto inputStreamOutput = new Output;
                auto inputStreamExitCode = this.inputStream.next(escopo, inputStreamOutput);
                if (inputStreamExitCode == ExitCode.Break)
                {
                    this.inputStream = null;
                    pipes.stdin.close();
                    continue;
                }
                else if (inputStreamExitCode == ExitCode.Skip)
                {
                    continue;
                }
                else if (inputStreamExitCode != ExitCode.Continue)
                {
                    throw new SystemProcessInputError(
                        escopo,
                        "Error on " ~ this.toString()
                        ~ " while reading from "
                        ~ inputStream.toString()
                        ~ " (exitCode " ~ inputStreamExitCode.to!string ~ ")",
                        returnCode,
                        inputStream
                    );
                }

                foreach (item; inputStreamOutput.items)
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
                    return ExitCode.Skip;
                }

                wait();
                _isRunning = false;

                if (returnCode != 0)
                {
                    throw new SystemProcessException(
                        escopo,
                        "Error while executing " ~ this.toString(),
                        returnCode,
                        this
                    );
                }
                else
                {
                    return ExitCode.Break;
                }
            }

            line = pipes.stdout.readln();

            if (line is null)
            {
                // XXX: this Skip is weird...
                return ExitCode.Skip;
            }
            else
            {
                break;
            }
        }

        output.items ~= new String(line.stripRight('\n'));
        return ExitCode.Continue;
    }
    void wait()
    {
        returnCode = pid.wait();
    }
}
