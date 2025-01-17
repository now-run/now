module now.nodes.document;

import core.runtime;

import std.algorithm.searching : endsWith, startsWith;
import std.file : exists, isFile, read;
import std.path : buildNormalizedPath, buildPath, dirName;
import std.parallelism : TaskPool;
import std.string : toStringz;
import std.uni : toLower, toUpper;


import now.nodes;

import now.base_command;
import now.escopo;
import now.grammar;
import now.procedure;
import now.shell_script;
import now.system_command;
import now.task;
import now.user_defined_type;
import now.library;


class Document : Dict {
    string title;
    string description;
    string sourcePath;
    Dict metadata;
    Dict data;
    Dict text;
    TaskPool taskPool;
    LogLevel logLevel = LogLevel.Info;

    Procedure[string] commands;
    BaseCommand[string] procedures;
    Task[string] tasks;
    Library[string] libraries;
    SubProgram[string] logFormats;
    SubProgram errorHandler;

    string[] nowPath;

    this(string title, string description, Dict metadata, Dict data)
    {
        log(": Document: ", title);
        this.type = ObjectType.Document;
        this.methods = dictMethods;
        this.typeName = "document";

        this.title = title;
        this.description = description;
        this.metadata = metadata;
        this.data = data;

        log(":: Document created");
    }
    this(string title, string description, Dict metadata)
    {
        log(": Document: ", title, " / ", description, " / ", metadata);
        this(title, description, metadata, new Dict());
    }
    this(string title, string description)
    {
        log(": Document: ", title, " / ", description);
        this(title, description, new Dict(), new Dict());
    }

    void initialize(Dict environmentVariables)
    {
        log("- Initializing document");
        this["env"] = environmentVariables;
        setNowPath(environmentVariables);

        setLogLevel(environmentVariables);

        importPackages();
        loadConfiguration(environmentVariables);

        loadConstants();
        loadTemplates();
        loadShells();
        loadTasks();
        loadProcedures();
        loadDocumentCommands();
        loadSystemCommands();
        loadText();
        loadLibraries();
        loadUserDefinedTypes();
        loadLoggingConfig();
        loadErrorHandler();
        loadDataSources();
    }

    void setLogLevel(Dict environmentVariables)
    {
        auto levelStr = environmentVariables.get!string(
            "LOG_LEVEL", null
        );
        if (levelStr !is null)
        {
            levelStr = levelStr.toLower;
            switch (levelStr)
            {
                case "debug":
                    logLevel = LogLevel.Debug;
                    break;
                case "":
                case "info":
                    logLevel = LogLevel.Info;
                    break;
                case "warning":
                    logLevel = LogLevel.Warning;
                    break;
                case "error":
                    logLevel = LogLevel.Error;
                    break;
                default:
                    auto escopo = new Escopo(this, "setLogLevel");
                    throw new InvalidException(
                        escopo,
                        "Unkown log level: " ~ levelStr
                    );
            }
            this["log_level"] = new String(levelStr);
        }
    }
    void setNowPath(Dict environmentVariables)
    {
        log("- Setting nowPath");
        auto parent = dirName(this.sourcePath.buildNormalizedPath);
        this["script_dir"] = new Path(parent);

        auto nowPath = environmentVariables.getOr!string(
            "NOW_PATH",
            delegate (Dict d)
            {
                // Default:
                // [script path, current path]
                auto pwd = d.get!string("PWD");
                return [parent, pwd].join(":");
            }
        );
        this.nowPath = nowPath.split(":");
    }
    void importPackages()
    {
        log("- Importing packages");
        auto packages = data.getOrCreate!Dict("packages");
        foreach (index, filenameItem; packages.values)
        {
            bool success = false;
            string filename = filenameItem.toString();
            log("-- ", index, ": ", filename);
            foreach (basedir; this.nowPath)
            {
                auto path = buildPath([basedir, filename]);
                // .isFile raises a FileException if the path
                // doesn't exist (so weird).
                if (path.exists && path.isFile)
                {
                    this.importPackage(path);
                    success = true;
                    break;
                }
            }
            if (!success)
            {
                throw new Exception(
                    "Could not load package " ~ filename ~ " ."
                );
            }
        }
        log("--- Packages imported.");
    }
    void loadConfiguration(Dict environmentVariables)
    {
        log("- Loading configuration");
        /*
        About [configuration]:
        - It must always follow the format "configuration/:key";
        - No sub-keys are allowed;
        - No "direct" configuration is allowed.
        */
        auto configuration = data.getOrCreate!Dict("configuration");
        foreach (configSectionName, configSection; configuration)
        {
            if (this.get(configSectionName, null) !is null)
            {
                throw new InvalidConfigurationException(
                    null,
                    "Configuration section"
                    ~ configSectionName
                    ~ " is repeated."
                );
            }
            log("- configuration/", configSectionName);
            auto dict = new Dict();
            this[configSectionName] = dict;
            // Example: configSectionName = "http"

            // "name" = host
            // "infoItem" = type, default value, etc. (before casting to Dict)
            foreach (name, infoItem; cast(Dict)configSection)
            {
                log("-- ", name);
                string envName = (configSectionName ~ "_" ~ name).toUpper;
                string envNameLower = (configSectionName ~ "_" ~ name).toLower;
                Item finalValue;

                Item *envValuePtr = (envName in environmentVariables.values);
                if (envValuePtr !is null)
                {
                    finalValue = *envValuePtr;
                }
                else if (infoItem.type != ObjectType.Dict)
                {
                    finalValue = infoItem;
                }
                else
                {
                    auto info = cast(Dict)infoItem;
                    Item* valuePtr = ("default" in info.values);
                    if (valuePtr !is null)
                    {
                        // (http . port) = 5000
                        finalValue = *valuePtr;
                    }
                    else
                    {
                        throw new InvalidConfigurationException(
                            null,
                            "Configuration "
                            ~ configSectionName ~ "/" ~ name
                            ~ " not found. The environment variable "
                            ~ envName
                            ~ " should be set."
                        );
                    }
                }
                // ($client . password) -> x123
                dict[name] = finalValue;
                // val "CLIENT_PASSWORD" -> x123
                this[envName] = finalValue;
                // val "client_password" -> x123
                this[envNameLower] = finalValue;
                // $password -> x123
                log("document.", name, "=", finalValue);
                this[name] = finalValue;
            }
        }
    }
    void loadConstants()
    {
        log("- Loading constants");

        auto constants = data.getOrCreate!Dict("constants");
        foreach (sectionName, section; constants)
        {
            if (section.type != ObjectType.Dict)
            {
                this[sectionName] = section;
            }
            else
            {
                auto sectionDict = cast(Dict)section;
                Dict currentSection;
                try
                {
                    currentSection = this.get!Dict(sectionName);
                }
                catch (NotFoundException ex)
                {
                    currentSection = new Dict();
                    this[sectionName] = cast(Dict)section;
                    continue;
                }
                // else:
                currentSection.update(cast(Dict)section);
            }
        }
    }
    void loadTemplates()
    {
        log("- Loading templates");

        auto templates = data.getOrCreate!Dict("templates");
        foreach (templateName, infoItem; templates.values)
        {
            log("-- templateName: ", templateName);
            auto templateInfo = cast(Dict)infoItem;
            templates[templateName] = parseTemplate(
                templateName, templateInfo, templates
            );
        }
    }
    void loadShells()
    {
        log("- Loading shells");

        auto shells = data.getOrCreate!Dict("shells");
        foreach (shellName, infoItem; shells.values)
        {
            auto shellInfo = cast(Dict)infoItem;
            log("-- shell ", shellName, " <- ", shellInfo);

            auto command = shellInfo.get!List("command", null);
            if (command is null)
            {
                log("--- command is null!");
                auto cmdDict = new Dict();
                shellInfo["command"] = cmdDict;
                // default options for every shell:
                // (works fine on bash)
                cmdDict["-"] = new String(shellName);
                cmdDict["-"] = new String("-c");
                cmdDict["-"] = new Reference("script_body");
                if (!shellName.startsWith("ksh"))
                {
                    cmdDict["-"] = new Reference("script_name");
                }
            }
            log("--- command: ", shellInfo["command"]);

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
                this.procedures[scriptName] = new ShellScript(
                    shellName, shellInfo, scriptName, scriptInfo, this
                );
            }
        }
    }
    void loadTasks()
    {
        log("- Loading tasks");

        // The document dict is loaded, now
        // act accordingly on each different section.
        auto tasks = data.getOrCreate!Dict("tasks");
        if (tasks.length > 0)
        {
            // XXX: maybe allow user to configure it???
            // Maybe not?
            // Probably not.
            this.taskPool = new TaskPool();
            this.taskPool.isDaemon = true;
        }
        foreach (name, infoItem; tasks.values)
        {
            log("-- ", name);
            auto info = cast(Dict)infoItem;
            this.tasks[name] = new Task(name, info, this.taskPool);
        }
    }
    void loadProcedures()
    {
        log("- Loading procedures");

        // The document dict is loaded, now
        // act accordingly on each different section.
        auto procedures = data.getOrCreate!Dict("procedures");
        foreach (name, infoItem; procedures.values)
        {
            log("-- ", name);
            auto info = cast(Dict)infoItem;
            this.procedures[name] = new Procedure(name, info);
        }
    }
    void loadDocumentCommands()
    {
        log("- Loading commands");

        auto commandsDict = data.getOrCreate!Dict("commands");
        foreach (name, infoItem; commandsDict.values)
        {
            log("-- ", name);
            auto info = cast(Dict)infoItem;
            commands[name] = new Procedure(name, info);
        }
    }
    void loadSystemCommands()
    {
        log("- Preparing system commands");

        auto system_commands = data.getOrCreate!Dict("system_commands");
        foreach (name, infoItem; system_commands.values)
        {
            log("-- ", name);
            auto info = cast(Dict)infoItem;
            if (info is null)
            {
                throw new Exception(
                    "system_commands/" ~ name
                    ~ ".info is null"
                );
            }
            // XXX: is it correct to save procedures and
            // syscmds in the same place???
            this.procedures[name] = new SystemCommand(name, info, this);
        }
    }
    void loadText()
    {
        log("- Collecting Text");

        this.text = new Dict();

        // this.text["title"] = new String(this.title);
        // this.text["description"] = new String(this.description);
        this.text[this.title] = new String(this.description);

        foreach (key, value; data)
        {
            auto firstLetter = key[0];
            if (firstLetter >= 'A' && firstLetter <= 'Z')
            {
                text[key] = value;
            }
        }

        this["text"] = this.text;
    }
    void loadErrorHandler()
    {
        log("- Loading error handler");
        auto handler = data.get!Dict("on.error", null);
        if (handler is null)
        {
            return;
        }

        auto body = handler["body"];
        auto parser = new NowParser(body.toString);
        auto subprogram = parser.consumeSubProgram;
        errorHandler = subprogram;
    }
    void loadLoggingConfig()
    {
        log("- Loading logging config");
        auto config = data.get!Dict("logging", null);
        if (config is null)
        {
            return;
        }

        auto formats = config.get!Dict("formats", null);
        if (formats !is null)
        {
            foreach (name, infoItem; formats)
            {
                log("-- format: ", name);
                auto format = cast(Dict)infoItem;
                auto body = format["body"];
                auto parser = new NowParser(body.toString);
                auto subprogram = parser.consumeSubProgram;
                logFormats[name] = subprogram;
            }
        }
    }
    void loadDataSources()
    {
        log("- Loading data_sources");
        auto dataSources = data.get!Dict("data_sources", null);
        if (dataSources is null)
        {
            return;
        }

        foreach (key, value; dataSources)
        {
            auto section = cast(Dict)value;
            auto parser = new NowParser(section["body"].toString);
            // XXX: not sure if this is right:
            parser.line = value.documentLineNumber;

            auto subprogram = parser.consumeSubProgram();
            auto escopo = new Escopo(this, key);
            auto output = new Output();
            auto exitCode = subprogram.run(escopo, output);

            if (exitCode == ExitCode.Return)
            {
                this[key] = output.items;
            }
        }
    }
    void loadLibraries()
    {
        log("- Preparing libraries");

        auto libraries = data.getOrCreate!Dict("libraries");
        foreach (name, infoItem; libraries)
        {
            log("-- ", name);
            auto info = cast(Dict)infoItem;
            if (info is null)
            {
                throw new Exception(
                    "libraries/" ~ name
                    ~ ".info is null"
                );
            }
            // XXX: is it correct to save procedures and
            // syscmds in the same place???
            auto library = new Library(name, info, this);
            library.spawn(this);
            this.libraries[name] = library;
            this.procedures[name] = library;
        }
    }
    void loadUserDefinedTypes()
    {
        log("- Loading user-defined types");

        // The document dict is loaded, now
        // act accordingly on each different section.
        auto types = data.getOrCreate!Dict("types");
        foreach (name, infoItem; types.values)
        {
            log("-- ", name);
            auto info = cast(Dict)infoItem;
            this.procedures[name] = new UserDefinedType(name, info);
        }
    }

    // Conversions
    override string toString()
    {
        return this.title;
    }

    // Commands (for command line)
    Procedure getCommand(string name)
    {
        auto commandPtr = (name in commands);
        if (commandPtr !is null)
        {
            return *commandPtr;
        }
        else
        {
            return null;
        }
    }
    ExitCode runProcedure(string path, Input input, Output output)
    {
        if (auto procPtr = (path in this.procedures))
        {
            auto proc = *procPtr;
            return proc.run(path, input, output);
        }

        if (auto taskPtr = (path in this.tasks))
        {
            auto task = cast(Task)(*taskPtr);
            return task.run(path, input, output);
        }

        if (auto cmdPtr = (path in builtinCommands))
        {
            auto cmd = *cmdPtr;
            auto exitCode = cmd(path, input, output);
            return exitCode;
        }

        throw new ProcedureNotFoundException(
            input.escopo,
            "Procedure not found: " ~ path
        );
    }

    // Packages
    void importPackage(string path)
    {
        if (path.endsWith(".now"))
        {
            return importNowLibrary(path);
        }
    }

    void importNowLibrary(string path)
    {
        auto parser = new NowParser(path.read().to!string);
        auto library = parser.run();
        // Merge the library into the document:
        foreach (key, value; library.data)
        {
            this.data.on(
                key,
                delegate (Item localValue)
                {
                    // Found both locally and in library:
                    this.dataMerge(key, localValue, value);
                },
                delegate ()
                {
                    // Found in library, not found locally:
                    this.data[key] = value;
                }
            );
        }
    }
    void dataMerge(string key, Item localValue, Item otherValue)
    {
        if (otherValue.type != ObjectType.Dict)
        {
            this.data[key] = otherValue;
        }
        else if (localValue.type != ObjectType.Dict)
        {
            this.data[key] = otherValue;
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
}
