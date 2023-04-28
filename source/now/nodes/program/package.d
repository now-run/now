module now.nodes.program;

import core.sys.posix.dlfcn;
import std.algorithm : each;
import std.algorithm.searching : endsWith;
import std.file : isFile, read;
import std.path : buildPath;
import std.string : toStringz;
import std.uni : toUpper;

import now.grammar;
import now.nodes;


class Program : Dict {
    // CLI commands:
    Procedure[string] subCommands;
    // Procedures:
    BaseCommand[string] procedures;
    // Global commands:
    CommandsMap globalCommands;

    string[] nowPath;

    this()
    {
        this.type = ObjectType.Document;
        this.commands = dictCommands;
        this.typeName = "document";
    }

    void initialize(CommandsMap commands, Dict environmentVariables)
    {
        debug {stderr.writeln("Initializing program");}
        this.globalCommands = commands;

        debug {stderr.writeln("Setting nowPath");}
        auto nowPath = environmentVariables.get!String(
            "NOW_PATH",
            delegate (Dict d)
            {
                auto pwd = d["PWD"].toString();
                return new String(pwd ~ "/now");
            }
        ).toString();
        this.nowPath = nowPath.split(":");

        // TODO: break all these sections in methods
        debug {stderr.writeln("Importing packages");}
        auto packages = this.getOrCreate!Dict("packages");
        foreach (index, filenameItem; packages.values)
        {
            bool success = false;
            string filename = filenameItem.toString();
            foreach (basedir; this.nowPath)
            {
                auto path = buildPath([basedir.to!string, filename]);
                if (path.isFile)
                {
                    this.importPackage(path);
                    success = true;
                    break;
                }
            }
            if (!success)
            {
                throw new Exception(
                    "Could not load package " ~ filename ~ "."
                );
            }
        }

        debug {stderr.writeln("Adjusting configuration");}
        /*
        About [configuration]:
        - It must always follow the format "configuration/:key";
        - No sub-keys are allowed;
        - No "direct" configuration is allowed.
        */
        auto config = this.getOrCreate!Dict("configuration");
        foreach (configSectionName, configSection; config.values)
        {
            // Make sure the subDict exists:
            this.getOrCreate!Dict(configSectionName);

            // configSectionName = http
            auto d = cast(Dict)configSection;
            foreach (name, infoItem; d.values)
            {
                // name = host
                if (infoItem.type != ObjectType.Dict)
                {
                    continue;
                }

                string envName = (configSectionName ~ "_" ~ name).toUpper;
                debug {stderr.writeln("envName:", envName);}
                Item *envValuePtr = (envName in environmentVariables.values);
                if (envValuePtr !is null)
                {
                    String envValue = cast(String)(*envValuePtr);
                    debug {stderr.writeln(" -->", envValue);}
                    this[[configSectionName, name]] = envValue;
                    this[envName] = envValue;
                }
                else
                {
                    auto info = cast(Dict)infoItem;
                    Item* valuePtr = ("default" in info.values);
                    if (valuePtr !is null)
                    {
                        Item value = *valuePtr;

                        // http.port = 5000
                        this[[configSectionName, name]] = value;
                    }
                    else
                    {
                        throw new InvalidConfigurationException(
                            "Configuration "
                            ~ configSectionName ~ "/" ~ name
                            ~ " not found. The environment variable "
                            ~ envName
                            ~ " should be set."
                        );
                    }
                }
            }
        }

        debug {stderr.writeln("Adjusting constants");}

        auto constants = this.getOrCreate!Dict("constants");
        foreach (sectionName, section; constants.values)
        {
            if (section.type == ObjectType.Dict)
            {
                auto sectionDict = cast(Dict)section;
                this.on(
                    sectionName,
                    // If it already exists:
                    delegate (Item value) {
                        auto d = cast(Dict)value;
                        foreach (k, v; sectionDict.values)
                        {
                            d[k] = v;
                        }
                    },
                    // If doesn't exist:
                    delegate () {
                        this[sectionName] = section;
                    }
                );
            }
            else
            {
                this[sectionName] = section;
            }
        }

        debug {stderr.writeln("Adjusting templates");}
        auto templates = this.getOrCreate!Dict("templates");
        foreach (templateName, infoItem; templates.values)
        {
            auto templateInfo = cast(Dict)infoItem;
            templates[templateName] = parseTemplate(
                templateName, templateInfo, templates
            );
        }

        debug {stderr.writeln("Adjusting shells");}
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

        debug {stderr.writeln("Adjusting procedures");}

        // The program dict is loaded, now
        // act accordingly on each different section.
        auto procedures = this.getOrCreate!Dict("procedures");
        foreach (name, infoItem; procedures.values)
        {
            auto info = cast(Dict)infoItem;
            this.procedures[name] = new Procedure(name, info);
        }

        debug {stderr.writeln("Adjusting commands");}

        auto commandsDict = this.getOrCreate!Dict("commands");
        foreach (name, infoItem; commandsDict.values)
        {
            auto info = cast(Dict)infoItem;
            subCommands[name] = new Procedure(name, info);

        }

        debug {stderr.writeln("Preparing system commands");}

        auto system_commands = this.getOrCreate!Dict("system_commands");
        foreach (name, infoItem; system_commands.values)
        {
            auto info = cast(Dict)infoItem;
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

        debug {stderr.writeln("Collecting Text");}
        auto text = this.getOrCreate!Dict("text");
        foreach (name; this.order)
        {
            if (name[0] >= 'A' && name[0] <= 'Z')
            {
                text[name] = this[name];
                this.remove(name);
            }
        }
    }

    // Conversions
    override string toString()
    {
        return "document " ~ this.get!String(
            ["document","name"],
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

        // Or a system command:
        // TODO

        context.error(
            "Command `" ~ path ~ "` not found.",
            ErrorCode.CommandNotFound,
            ""
        );
        return context;
    }

    // Packages
    void importPackage(string path)
    {
        if (path.endsWith(".so"))
        {
            return importSharedLibrary(path);
        }
        else
        {
            return importNowLibrary(path);
        }
    }
    void importNowLibrary(string path)
    {
        auto parser = new NowParser(path.read().to!string);
        auto library = parser.run();
        // Merge the library into the program:
        foreach (key, value; library.values)
        {
            this.on(
                key,
                delegate (Item localValue)
                {
                    // Found both locally and in library:
                    this.merge(key, localValue, value);
                },
                delegate ()
                {
                    // Found in library, not found locally:
                    this[key] = value;
                }
            );
        }
    }
    void merge(string key, Item localValue, Item otherValue)
    {
        if (otherValue.type != ObjectType.Dict)
        {
            this[key] = otherValue;
        }
        else if (localValue.type != ObjectType.Dict)
        {
            this[key] = otherValue;
        }
        else
        {
            auto localDict = cast(Dict)localValue;
            auto otherDict = cast(Dict)otherValue;
            foreach (otherKey, value; otherDict.values)
            {
                localDict[otherKey] = value;
            }
        }
    }
    void importSharedLibrary(string path)
    {
        // Clean up any old error messages:
        dlerror();

        // lh = "library handler"
        void* lh = dlopen(path.toStringz, RTLD_LAZY);

        auto error = dlerror();
        if (error !is null)
        {
            // lastError = cast(char *)error;
            throw new Exception(" dlerror: " ~ error.to!string);
        }

        // Initialize the package:
        auto initPackage = cast(CommandsMap function(Program))dlsym(
            lh, "init"
        );

        error = dlerror();
        if (error !is null)
        {
            throw new Exception("dlsym error: " ~ to!string(error));
        }
        initPackage(this);
    }
}
