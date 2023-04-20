module now.commands.csv;

import std.algorithm.mutation : stripRight;
import std.array : replace;

import now.commands;
import now.nodes;
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
    commands["csv.decode"] = function (string path, Context context)
    {
        string content = context.pop!string();
        auto parser = new CsvParser(content);
        return context.push(parser.run());
    };
    commands["csv.encode"] = function (string path, Context context)
    {
        auto source = context.pop!List();
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
                        value = value.replace("\"", "\\\"");
                    }
                    items ~= "\"" ~ value ~ "\"";
                }
                else
                {
                    items ~= item.toString();
                }
            }
            s ~= items.join(",");
            s ~= "\n";
        }

        return context.push(s);
    };
}
