module now.commands.dotenv;

import std.file;
import now.commands.ini : IniParser;

import now;


class DotEnvParser : IniParser
{
    this(string code)
    {
        super(code);
        this.defaultEol = '\n';
    }

    override Dict run()
    {
        consumeWhitespaces();
        return consumeSectionBody();
    }
}


Dict parseDotEnv (string filepath)
{
    string content = filepath.readText;
    auto parser = new DotEnvParser(content);
    return parser.run();
}


void loadDotEnvCommands(CommandsMap commands)
{
    commands["dotenv.load"] = function(string path, Input input, Output output)
    {
        /*
        This command sets variables in the global $env dict.

        > dotenv.load ".env.localdev"
        . ($env . key_in_dotenv_file) == value_in_dotenv_file
        */
        auto document = input.escopo.document;
        auto envItem = document["env"];
        auto env = cast(Dict)envItem;

        if (input.items.length == 0)
        {
            input.items ~= new String(".env");
        }

        foreach (item; input.popAll)
        {
            string filepath = item.toString;
            auto data = parseDotEnv(filepath);
            foreach (key, value; data)
            {
                log("env[", key, "] = ", value);
                env[key] = value;
            }
        }

        document["env"] = env;
        document.loadConfiguration(env, true);

        return ExitCode.Success;
    };
    commands["dotenv.read"] = function(string path, Input input, Output output)
    {
        /*
        > dotenv.read ".env.localdev"
        dict (key_in_dotenv_file = value_in_dotenv_file)
        */
        auto result = new Dict();

        if (input.items.length == 0)
        {
            input.items ~= new String(".env");
        }

        foreach (item; input.popAll)
        {
            string filepath = item.toString;
            auto data = parseDotEnv(filepath);
            foreach (key, value; data)
            {
                log("result[", key, "] = ", value);
                result[key] = value;
            }
        }

        output.push(result);
        return ExitCode.Success;
    };
    commands["dotenv.decode"] = function(string path, Input input, Output output)
    {
        /*
        > dotenv.read "a = b"
        dict (a = b)
        */
        auto result = new Dict();

        foreach (item; input.popAll)
        {
            auto s = item.toString;
            auto parser = new DotEnvParser(s);
            auto data = parser.run();
            foreach (key, value; data)
            {
                log("result[", key, "] = ", value);
                result[key] = value;
            }
        }

        output.push(result);
        return ExitCode.Success;
    };
}
