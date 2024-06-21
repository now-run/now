module now.commands.csv;


import std.algorithm.mutation : stripRight;
import std.array : replace;

import now;
import now.commands;
import now.parser;


class CsvParser : Parser
{
    char separator;

    this(string code, char separator=',')
    {
        super(code);
        this.separator = separator;
    }

    List run()
    {
        consumeWhitespaces();
        Items items;

        while (!eof)
        {
            items ~= new List(consumeTuple());
        }

        return new List(items);
    }
    Items consumeTuple()
    {
        Items items;
        while (!eof && currentChar != EOL)
        {
            auto opener = separator;
            bool isEnclosed = false;
            if (currentChar.among('"', '\''))
            {
                opener = consumeChar();
                isEnclosed = true;
            }
            auto item = consumeString(opener, true);
            items ~= item;
            if (isEnclosed) consumeChar();
            if (currentChar == separator) consumeChar();
        }
        if (!eof) consumeChar();
        return items;
    }
}


void loadCsvCommands(CommandsMap commands)
{
    commands["csv.decode"] = function (string path, Input input, Output output)
    {
        // TODO:
        // 1- accept multiple arguments;
        // 2- if argument is Path, use a CsvReader class.
        string content = input.pop!string();

        char separator = ',';
        auto separator_ptr = ("separator" in input.kwargs);
        if (separator_ptr !is null)
        {
            separator = (*separator_ptr).toString[0];
        }

        auto parser = new CsvParser(content, separator);
        output.push(parser.run());
        return ExitCode.Success;
    };
    commands["csv.encode"] = function (string path, Input input, Output output)
    {
        auto source = input.pop!List();

        string separator = ",";
        auto separator_ptr = ("separator" in input.kwargs);
        if (separator_ptr !is null)
        {
            separator = (*separator_ptr).toString;
        }

        string s;
        foreach (lineItem; source.items)
        {
            auto line = cast(List)lineItem;
            string[] items;
            foreach (item; line.items)
            {
                if (item.type == ObjectType.String)
                {
                    auto S = cast(String)item;
                    auto value = S.toString();

                    if (value.canFind("\""))
                    {
                        // TODO: create/use a proper escaping function
                        value = value.replace("\"", "\\\"");
                    }
                    items ~= "\"" ~ value ~ "\"";
                }
                else
                {
                    items ~= item.toString();
                }
            }
            s ~= items.join(separator);
            s ~= "\n";
        }

        output.push(s);
        return ExitCode.Success;
    };
}
