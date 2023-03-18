module now.nodes.program;


import std.algorithm : each;
import std.uni : toUpper;

import now.nodes;
import now.packages;


class Program : Dict {
    // CLI commands:
    Procedure[string] subCommands;
    // Procedures:
    BaseCommand[string] procedures;
    // Global commands:
    CommandsMap globalCommands;

    this()
    {
        this.type = ObjectType.Program;
        this.commands = dictCommands;
        this.typeName = "program";
    }

    void initialize(CommandsMap commands, Dict environmentVariables)
    {
        debug {
            stderr.writeln("Initializing program");
        }
        this.globalCommands = commands;

        // TODO: break all these sections in methods
        debug {
            stderr.writeln("Adjusting configuration");
        }
        /*
        About [configuration]:
        - It must always follow the format "configuration/:key";
        - No sub-keys are allowed;
        - No "direct" configuration is allowed.
        */
        auto config = this.getOrCreate!Dict("configuration");
        foreach (configSectionName, configSection; config.values)
        {
            auto d = cast(Dict)configSection;
            foreach (name, infoItem; d.values)
            {
                if (infoItem.type != ObjectType.Dict)
                {
                    continue;
                }

                // Make sure the subDict exists:
                this.getOrCreate!Dict([configSectionName, name]);

                auto info = cast(Dict)infoItem;
                Item* valuePtr = ("default" in info.values);
                if (valuePtr !is null)
                {
                    Item value = *valuePtr;

                    // http.port = 5000
                    this[[configSectionName, name]] = value;
                }

                string envName = (configSectionName ~ "_" ~ name).toUpper;
                debug {
                    stderr.writeln("envName:", envName);
                }
                Item *envValuePtr = (envName in environmentVariables.values);
                if (envValuePtr !is null)
                {
                    String envValue = cast(String)(*envValuePtr);
                    debug {
                        stderr.writeln(" -->", envValue);
                    }
                    this[[configSectionName, name]] = envValue;
                    this[envName] = envValue;
                }
            }
        }

        debug {
            stderr.writeln("Adjusting constants");
        }

        auto constants = this.getOrCreate!Dict("constants");
        foreach (sectionName, section; constants.values)
        {
            this[sectionName] = section;
        }

        debug {
            stderr.writeln("Adjusting shells");
        }
        auto shells = this.getOrCreate!Dict("shells");
        foreach (shellName, infoItem; shells.values)
        {
            auto shellInfo = cast(Dict)infoItem;

            shellInfo.get!Dict(
                "command",
                delegate (Dict d) {
                    auto cmdDict = new Dict();
                    shellInfo["command"] = cmdDict;
                    // default options for every shell:
                    // (works fine on bash)
                    cmdDict["-"] = new String(shellName);
                    cmdDict["-"] = new String("-c");
                    cmdDict["-"] = new SubstAtom("script_body");
                    if (shellName[0..3] != "ksh")
                    {
                        cmdDict["-"] = new SubstAtom("script_name");
                    }
                    return cast(Dict)null;
                }
            );

            // Scripts for this shell:
            auto scripts = shellInfo.getOrCreate!Dict("scripts");
            foreach (scriptName, scriptInfoItem; scripts.values)
            {
                /*
                XXX: since we are passing shellInfo IMMEDIATELY,
                we can't declare the shell itself AFTER the scripts
                were declared (we could, but it'd be innefective).
                */
                auto scriptInfo = cast(Dict)scriptInfoItem;
                debug {
                    stderr.writeln("scripts/", scriptName, ": ", scriptInfo);
                }
                this.procedures[scriptName] = new ShellScript(
                    shellName, shellInfo, scriptName, scriptInfo
                );
            }
        }

        debug {
            stderr.writeln("Adjusting procedures");
        }

        // The program dict is loaded, now
        // act accordingly on each different section.
        auto procedures = this.getOrCreate!Dict("procedures");
        foreach (name, infoItem; procedures.values)
        {
            auto info = cast(Dict)infoItem;
            this.procedures[name] = new Procedure(name, info);
        }

        debug {
            stderr.writeln("Adjusting commands");
        }

        auto commandsDict = this.getOrCreate!Dict("commands");
        foreach (name, infoItem; commandsDict.values)
        {
            auto info = cast(Dict)infoItem;
            subCommands[name] = new Procedure(name, info);

        }

        debug {
            stderr.writeln("Preparing system commands");
        }

        auto system_commands = this.getOrCreate!Dict("system_commands");
        foreach (name, infoItem; system_commands.values)
        {
            auto info = cast(Dict)infoItem;
            debug {
                stderr.writeln("system_commands/", name, ".infoItem:", infoItem);
                stderr.writeln("  ", infoItem.type);
                stderr.writeln("  becomes: ", info);
            }
            if (info is null)
            {
                throw new Exception(
                    "system_commands/" ~ name
                    ~ ".info is null"
                );
            }
            // XXX: is it correct to save procedures and
            // syscmdcalls in the same place???
            this.procedures[name] = new SystemCommand(name, info);
        }

        debug {
            stderr.writeln("Importing external packages");
        }

        auto packages = this.getOrCreate!Dict(["dependencies","packages"]);
        foreach (packageName, packageInfo; packages.values)
        {
            /*
            We're not installing any packages here.
            */
            this.importModule(packageName);
        }
    }

    // Conversions
    override string toString()
    {
        return "program " ~ this.get!String(
            ["program","name"],
            delegate (Dict d) {
                return new String("PROGRAM WITHOUT A NAME");
            }
        ).toString();
    }

    override Context runCommand(string path, Context context)
    {
        // If it's a procedure:
        auto procPtr = (path in this.procedures);
        if (procPtr !is null)
        {
            auto proc = *procPtr;
            return proc.run(path, context);
        }

        // Or if it's a built-in command:
        auto cmdPtr = (path in this.globalCommands);
        if (cmdPtr !is null)
        {
            auto cmd = *cmdPtr;
            return cmd(path, context);
        }

        context.error(
            "Command `" ~ path ~ "` not found.",
            ErrorCode.CommandNotFound.to!int,
            ""
        );
        return context;
    }

    // Packages
    string[] getDependenciesPath()
    {
        // TODO: the correct is $program_dir/.now!

        // For now...
        // $current_dir/.now
        return [".now"];

        // TODO: check for $program . dependencies . path
    }
}
