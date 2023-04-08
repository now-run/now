module now.commands.ini;

import std.algorithm.mutation : stripRight;

import now.commands;
import now.nodes;
import now.parser;


class IniParser : Parser
{
    this(string code)
    {
        super(code);
    }

    Dict run()
    {
        auto dict = new Dict();

        consumeWhitespaces();
        while (!eof)
        {
            auto key = consumeSectionHeader();
            consumeWhitespaces();
            dict[key] = consumeSectionBody();
        }

        return dict;
    }
    string consumeSectionHeader()
    {
        string s;
        auto opener = consumeChar();
        assert (opener == '[');
        while (!eof && currentChar != ']')
        {
            s ~= consumeChar();
        }
        auto closer = consumeChar();
        assert (closer == ']');
        return s;
    }
    Dict consumeSectionBody()
    {
        auto dict = new Dict();
        while (!eof && currentChar != '[')
        {
            string key;
            while (!eof && currentChar != '=')
            {
                key ~= consumeChar();
            }
            if (eof) break;
            key = key.stripRight(' ');
            consumeChar();  // '='
            consumeBlankspaces();
            auto closer = ';';
            bool isEnclosed = false;
            if (currentChar.among('"', '\''))
            {
                closer = consumeChar();
                isEnclosed = true;
            }
            auto value = consume_string(closer);
            if (!isEnclosed)
            {
                value = value.stripRight(' ');
            }
            dict[key] = new String(value);
            // Whatever comes next, we ignore:
            consumeLine();
        }
        return dict;
    }
}


void loadIniCommands(CommandsMap commands)
{
    commands["ini.decode"] = function (string path, Context context)
    {
        string content = context.pop!string();
        auto parser = new IniParser(content);
        return context.push(parser.run());
    };
    commands["ini.encode"] = function (string path, Context context)
    {
        return context.error(
            "Not implemented",
            ErrorCode.NotImplemented,
            ""
        );
    };
}
