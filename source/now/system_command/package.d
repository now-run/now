module now.system_command;


import std.algorithm.mutation : stripRight;
import std.json;
import std.process;
import std.stdio : readln;

import now;
import now.json;


MethodsMap systemProcessMethods;


class SystemCommand : BaseCommand
{
    string[] which;
    List command;
    string optionPrefix;
    string keyValueSeparator;
    bool takeOver;
    bool takeOverOutput;
    bool keepStdinOpen;
    string returns;
    bool isolateEnv;
    Document document;
    Item workdir;

    this(string name, Dict info, Document document)
    {
        super(name, info);
        this.document = document;

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

        auto installMessage = info.get!String("install_message", null);

        auto returnsItem = info.get("returns", null);
        log("returnsItem:", returnsItem);
        if (returnsItem !is null)
        {
            returns = returnsItem.toString;
        }
        else
        {
            returns = "process";
        }
        log("    returns:", returns);

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
                bool should_warn = document.metadata.get!Boolean("which_warnings", new Boolean(true)).toBool;
                if (should_warn)
                {
                    stderr.writeln(
                        "Warning: system_commands/" ~ name
                        ~ ": `which` failed with code " ~ status.to!string
                        ~ "; command line was: " ~ whichCmdLine.to!string,
                    );

                    if (installMessage !is null)
                    {
                        stderr.writeln(
                            installMessage.toString,
                        );
                    }
                    stderr.writeln();
                }

            }
        }

        /*
        Option prefix and key/value separator follows
        GNU conventions by default ("--key=value").
        */
        this.optionPrefix = info.get!string("option_prefix", "--");
        this.keyValueSeparator = info.get!string("key_value_separator", "=");

        this.takeOver = info.get!bool("take_over", false);
        this.takeOverOutput = info.get!bool("take_over_output", false);
        this.keepStdinOpen = info.get!bool("keep_stdin_open", false);
        this.isolateEnv = info.get!bool("isolate_env", false);
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
            inputStream = new ItemsRangesRange(input.inputs);
        }
        log("SystemCommand.inputStream:", inputStream);

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
        log("SystemCommand.input.escopo:", input.escopo);
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
            log("    env[", key, "] = ", env[key]);
        }

        // Evaluate workdir:
        string workdirStr = null;
        if (workdir !is null)
        {
            auto workdirOutput = workdir.evaluate(input.escopo);
            workdirStr = workdirOutput.front.toString();
        }

        log(" -- inputStream: ", inputStream);

        auto process = new SystemProcess(
            cmdline, inputStream, env, workdirStr,
            takeOver, keepStdinOpen, takeOverOutput, isolateEnv
        );

        if (returns is null)
        {
            output.push(process);
        }
        else
        {
            log("returns: ", returns, " / ", returns.length);
            switch (returns)
            {
                case "string":
                    output.push(process.getOutput(input.escopo));
                    break;
                case "json":
                    auto outputString = process.getOutput(input.escopo);
                    auto json = parseJSON(outputString);
                    auto object = JsonToItem(json);
                    output.push(object);
                    break;
                case "process":
                    output.push(process);
                    break;
                default:
                    throw new InvalidArgumentsException(
                        input.escopo,
                        "Unknown return type for "
                        ~ this.name ~ ": "
                        ~ returns
                    );
            }
        }
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
    string workdir;
    bool takeOver;
    bool keepStdinOpen;
    bool takeOverOutput;
    bool isolateEnv;
    string[string] env;
    int returnCode = 0;
    bool _isRunning = true;

    this(
        string[] cmdline,
        Item inputStream=null,
        string[string] env=null,
        string workdir=null,
        bool takeOver=false,
        bool keepStdinOpen=false,
        bool takeOverOutput=false,
        bool isolateEnv=false,
    )
    {
        log(": SystemProcess: ", cmdline);

        this.type = ObjectType.SystemProcess;
        this.typeName = "system_process";
        this.methods = systemProcessMethods;

        this.env = env;
        this.inputStream = inputStream;

        this.cmdline = cmdline;
        this.workdir = workdir;

        this.takeOver = takeOver;
        this.takeOverOutput = takeOverOutput;

        auto config = Config();
        if (isolateEnv)
        {
            config = Config.newEnv;
        }

        if (takeOver)
        {
            this.pid = spawnProcess(
                cmdline,
                env,
                config,
                workdir
            );
        }
        else
        {
            Redirect redirect;

            if (!this.takeOverOutput)
            {
                redirect |= Redirect.stdout;
                log("redirect: stdout");
            }
            if (inputStream !is null || keepStdinOpen)
            {
                redirect |= Redirect.stdin;
                log("redirect: stdin");
            }

            pipes = pipeProcess(
                cmdline,
                redirect,
                env,
                config,
                workdir
            );

            this.pid = pipes.pid;
        }
    }

    override string toString()
    {
        auto s = this.cmdline.join(" ");
        if (s.length > 512)
        {
            s = s[0..512] ~ " ...";
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
            auto w = this.pid.tryWait();
            _isRunning = !w.terminated;
            if (!_isRunning)
            {
                returnCode = w.status;
            }
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
                log("inputStreamExitCode:", inputStreamExitCode);
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
                    log("pipes.stdin.writeln:", s);
                    pipes.stdin.writeln(s);
                    pipes.stdin.flush();
                }
                continue;
            }

            if (takeOverOutput)
            {
                if (inputStream is null)
                {
                    return ExitCode.Continue;
                }
                else
                {
                    return ExitCode.Skip;
                }
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

            log("reading process stdout...");
            line = pipes.stdout.readln();
            log("pipes.stdout.readln <- ", line);

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
    string getOutput(Escopo escopo)
    {
        auto nextOutput = new Output;
        while (true)
        {
            auto exitCode = this.next(escopo, nextOutput);
            if (exitCode != ExitCode.Continue)
            {
                break;
            }
        }

        return nextOutput.items.map!(x => x.toString).join("\n");
    }
}
