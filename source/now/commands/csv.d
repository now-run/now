module now.commands.csv;

import std.algorithm.mutation : stripRight;

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
            items ~= consumeString(opener, true);
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
        return context.error(
            "Not implemented",
            ErrorCode.NotImplemented,
            ""
        );
    };
}
