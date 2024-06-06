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
            // XXX: check if this works:
            auto list = cast(List)item;
            foreach (cmdItem; list.items)
            {
                auto evaluationOutput = cmdItem.evaluate(escopo);
                whichCmdLine ~= evaluationOutput.front.toString();
            }
        }, delegate () {
            // TODO: run `which` (the system command) to
            // check if the requested command is available.
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
        // TESTE: all "args" were already used bound to
        // proper variables in this scope, so no need
        // to revisit it again.
        // arguments = input.args.map!(x => to!string(x)).array;
        // TODO: run further tests to make sure we really shouldn't
        // be revisiting input.args again.

        /*
        command {
            - "ls"
            - $options
            - $path
        }
        We must evaluate that before running.
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

        output.items ~= new SystemProcess(
            cmdline, arguments, inputStream, env, workdirStr, takeOver
        );
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
    string[] arguments;
    string[] cmdline;
    bool takeOver;
    string[string] env;
    int returnCode = 0;
    bool _isRunning;

    this(
        string[] cmdline,
        string[] arguments,
        Item inputStream=null,
        string[string] env=null,
        string workdir=null,
        bool takeOver=false
    )
    {
        log(": SystemProcess: ", cmdline);
        log(":     arguments: ", arguments);

        this.type = ObjectType.SystemProcess;
        this.typeName = "system_process";
        this.methods = systemProcessMethods;

        this.env = env;
        this.arguments = arguments;
        this.inputStream = inputStream;

        this.cmdline = cmdline;
        this.cmdline ~= arguments;

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
            return s[0..256] ~ " ...";
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

        output.push(line.stripRight('\n'));
        return ExitCode.Continue;
    }
    void wait()
    {
        returnCode = pid.wait();
    }
}
