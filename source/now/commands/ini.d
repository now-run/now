module now.commands.ini;

import std.string : split, strip, stripRight;

import now;
import now.commands;
import now.parser;


class IniParser : Parser
{
    char defaultEol = ';';
    char keySplitter = cast(char)null;

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
            while (!eof && !currentChar.among('=', '['))
            {
                key ~= consumeChar();
            }
            if (eof) break;
            log("ini.key=", key);
            key = key.strip();
            if (key.length == 0)
            {
                continue;
            }
            consumeChar();  // '='
            consumeWhitespaces();
            auto closer = this.defaultEol;
            bool isEnclosed = false;
            if (currentChar.among('"', '\''))
            {
                closer = consumeChar();
                isEnclosed = true;
            }
            log("  consume_string until [", closer.to!string, "]");
            auto value = consume_string(closer);
            if (!isEnclosed)
            {
                value = value.stripRight();
            }

            if (keySplitter)
            {
                auto parts = key.split(keySplitter);
                dict[parts] = new String(value);
            }
            else
            {
                dict[key] = new String(value);
            }
            log("  ", key, "=", value);
            // Whatever comes next, we ignore:
            if (!eof)
            {
                consumeLine();
            }
        }
        return dict;
    }
}


void loadIniCommands(CommandsMap commands)
{
    commands["ini.decode"] = function(string path, Input input, Output output)
    {
        string content = input.pop!string();

        auto parser = new IniParser(content);
        if (auto closerRef = ("eol" in input.kwargs))
        {
            auto closer = cast(String)(*closerRef);
            parser.defaultEol = closer.toString[0];
            log("IniParser.defaultEol:", parser.defaultEol);
        }
        if (auto keySplitRef = ("key_split" in input.kwargs))
        {
            parser.keySplitter = (cast(String)(*keySplitRef)).toString[0];
        }

        output.push(parser.run());
        return ExitCode.Success;
    };
    commands["ini.encode"] = function(string path, Input input, Output output)
    {
        throw new NotImplementedException(
            input.escopo,
            "Not implemented",
            -1,
        );
    };
}
