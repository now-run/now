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
    bool takeOver;
    Item workdir;

    this(string name, Dict info, Document document)
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
        this.workdir = info.get!Item("workdir", null);

        auto cmdItem = info.getOr(
            "command",
            delegate Item (d) {
                throw new Exception(
                    "commands/" ~ name
                    ~ " must declare a `command` value."
                );
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

        string [] whichCmdLine;
        auto escopo = new Escopo(document, this.name);
        info.on("which", delegate (item) {
            if (item.type == ObjectType.Boolean)
            {
                auto b = (cast(Boolean)item).toBool;
                if (b is true)
                {
                    // REPETITION!
                    whichCmdLine ~= "which";
                    auto evaluationOutput = this.command.items.front.evaluate(escopo);
                    whichCmdLine ~= evaluationOutput.front.toString();
                }
            }
            else if (item.type == ObjectType.List)
            {
                auto list = cast(List)item;
                foreach (cmdItem; list.items)
                {
                    auto evaluationOutput = cmdItem.evaluate(escopo);
                    whichCmdLine ~= evaluationOutput.front.toString();
                }
            }
        }, delegate () {
            whichCmdLine ~= "which";
            auto evaluationOutput = this.command.items.front.evaluate(escopo);
            whichCmdLine ~= evaluationOutput.front.toString();
        });

        int status;
        if (whichCmdLine.length)
        {
            try
            {
                auto p = execute(whichCmdLine);
                status = p.status;
            }
            catch (ProcessException ex)
            {
                status = -1;
            }
            if (status != 0)
            {
                throw new Exception(
                    "commands/" ~ name
                    ~ ": `which` failed with code " ~ status.to!string
                    ~ "; command line was: " ~ whichCmdLine.to!string
                );
            }
        }

        /*
        Option prefix and key/value separator follows
        GNU conventions by default ("--key=value").
        */
        this.optionPrefix = info.get!string("option_prefix", "--");
        this.keyValueSeparator = info.get!string("key_value_separator", "=");

        this.takeOver = info.get!bool("take_over", false);
    }

    override ExitCode doRun(string name, Input input, Output output)
    {
        Item inputStream;

        // We need this because we support event handling
        // (in the definition, like on.return or on.error)
        input.escopo.rootCommand = this;

        // Inputs:
        if (input.inputs.length == 1)
        {
            inputStream = input.inputs.front.range;
        }
        else if (input.inputs.length > 1)
        {
            throw new InvalidInputException(
                input.escopo,
                name ~ ": cannot handle multiple inputs",
            );
        }

        /*
        command {
            - "ls"
            - $options
            - $path
        }
        */
        auto cmdline = this.getCommandLine(input.escopo);

        // set each variable on this Escopo as
        // a environment variable:
        string[string] env;

        // input.escopo = whatever goes in `parameters`, basically.
        // also `args` and `inputs`.
        // (That is: it's the newly create scope, not the caller one.)
        foreach (key, value; input.escopo)
        {
            /*
            > set a 1
            env["a"] = "1"
            > set b 1 2 3
            env["b"] = "(1 2 3)"
            */
            if (value.type == ObjectType.Sequence)
            {
                auto sequence = cast(Sequence)value;
                auto l = sequence.items.length;
                if (l == 0)
                {
                    continue;
                }
                else if (l == 1)
                {
                    env[key] = sequence.items.front.toString;
                }
                else
                {
                    // Emulate a bash array:
                    env[key] = (
                        "("
                        ~ sequence.items.map!(x => x.toString()).join(" ")
                        ~ ")"
                    );
                }
            }
            else
            {
                env[key] = value.toString;
            }
        }

        // Evaluate workdir:
        string workdirStr = null;
        if (workdir !is null)
        {
            auto workdirOutput = workdir.evaluate(input.escopo);
            workdirStr = workdirOutput.front.toString();
        }

        log(" -- inputStream: ", inputStream);

        output.push(new SystemProcess(
            cmdline, inputStream, env, workdirStr, takeOver
        ));
        return ExitCode.Success;
    }

    string[] getCommandLine(Escopo escopo)
    {
        string[] cmdline;

        foreach (segment; command.items)
        {
            auto segmentOutput = segment.evaluate(escopo);
            // XXX: we PROBABLY have only one item, here:
            Item nextItem = segmentOutput.front;

            if (nextItem.type == ObjectType.List)
            {
                auto list = cast(List)nextItem;
                // Expand Lists inside the command arguments:
                cmdline ~= list.items.map!(x => x.toString()).array;
            }
            // dict (verbosity = 3)
            // -> "--verbosity=3"
            else if (nextItem.type == ObjectType.Dict)
            {
                auto dict = cast(Dict)nextItem;
                foreach (k, v; dict)
                {
                    Items vs;
                    if (v.type == ObjectType.List)
                    {
                        vs = (cast(List)v).items;
                    }
                    else
                    {
                        vs = [v];
                    }

                    foreach (iv; vs)
                    {
                        if (this.keyValueSeparator == " ")
                        {
                            cmdline ~= this.optionPrefix ~ k;
                            cmdline ~= iv.toString();
                        }
                        else
                        {
                            cmdline ~= this.optionPrefix
                                ~ k
                                ~ this.keyValueSeparator
                                ~ iv.toString();
                        }
                    }
                }
            }
            else
            {
                auto evaluationOutput = nextItem.evaluate(escopo);
                // XXX: what if evaluation returns a Sequence? Or a List?
                cmdline ~= evaluationOutput.front.toString();
            }
        }
        return cmdline;
    }

}


class SystemProcess : Item
{
    ProcessPipes pipes;
    std.process.Pid pid;
    Item inputStream;
    string[] cmdline;
    bool takeOver;
    string[string] env;
    int returnCode = 0;
    bool _isRunning;

    this(
        string[] cmdline,
        Item inputStream=null,
        string[string] env=null,
        string workdir=null,
        bool takeOver=false
    )
    {
        log(": SystemProcess: ", cmdline);

        this.type = ObjectType.SystemProcess;
        this.typeName = "system_process";
        this.methods = systemProcessMethods;

        this.env = env;
        this.inputStream = inputStream;

        this.cmdline = cmdline;

        if (takeOver)
        {
            this.pid = spawnProcess(
                cmdline,
                env,
                Config(),
                workdir
            );
        }
        else
        {
            Redirect redirect = Redirect.stdout;
            if (inputStream !is null)
            {
                redirect |= Redirect.stdin;
            }

            pipes = pipeProcess(
                cmdline,
                redirect,
                env,
                Config(),
                workdir
            );

            this.pid = pipes.pid;
        }
    }

    override string toString()
    {
        auto s = this.cmdline.join(" ");
        if (s.length > 256)
        {
            s = s[0..256] ~ " ...";
        }

        return "<SystemProcess: " ~ s ~ ">";
    }
    override Item range()
    {
        return this;
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

        output.push(line.stripRight('\n'));
        return ExitCode.Continue;
    }
    void wait()
    {
        returnCode = pid.wait();
    }
}
