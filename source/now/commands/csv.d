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
        Items items;

        consumeWhitespaces();
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
            auto item = consume_string(opener, true);

            // handle,the,"something in ""double quotes"" situation"
            if (isEnclosed)
            {
                consumeChar;
                while (!eof && currentChar == opener)
                {
                    // "abc""def""ghi"
                    //      ^
                    item ~= consumeChar;
                    item ~= consume_string(opener, true);

                    if (currentChar == opener)
                    {
                        consumeChar;
                    }
                }
            }
            items ~= new String(item);
            if (currentChar == separator) consumeChar();
        }
        if (!eof) consumeChar();
        return items;
    }
}


void loadCsvCommands(CommandsMap commands)
{
    commands["csv.decode"] = function(string path, Input input, Output output)
    {
        // TODO:
        // 1- accept multiple arguments;
        // 2- if argument is Path, use a CsvReader class.
        string content = input.pop!string();

        if (content.length == 0)
        {
            output.push(new List([]));
            return ExitCode.Success;
        }

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
    commands["csv.encode"] = function(string path, Input input, Output output)
    {
        auto source = input.pop!List();

        string separator = ",";
        auto separator_ptr = ("separator" in input.kwargs);
        if (separator_ptr !is null)
        {
            separator = (*separator_ptr).toString;
        }

        string[] encodedLines;
        foreach (line; source.items.map!(x => cast(List)x))
        {
            string[] items;
            foreach (item; line.items)
            {
                if (item.type == ObjectType.String)
                {
                    auto S = cast(String)item;
                    auto value = S.toString();

                    if (value.canFind("\""))
                    {
                        // XXX: using two adjacent double-quotes is the ...correct... way
                        // of escaping double quotes...
                        value = value.replace("\"", "\"\"");
                    }
                    items ~= "\"" ~ value ~ "\"";
                }
                else
                {
                    items ~= item.toString();
                }
            }
            encodedLines ~= items.join(separator);
        }

        output.push(encodedLines.join("\n"));
        return ExitCode.Success;
    };
}
