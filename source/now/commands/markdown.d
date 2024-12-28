module now.commands.markdown;


import std.string : rightJustify, tr;

import now;


string toMarkdown(Item item, int level=1)
{
    switch (item.type)
    {
        case ObjectType.List:
            auto list = cast(List)item;
            string result;
            foreach (subItem; list.items)
            {
                if (subItem.type == ObjectType.Dict)
                {
                     result ~= subItem.toMarkdown(level+1);
                }
                else if (subItem.type == ObjectType.List)
                {
                    result ~=  subItem.toMarkdown(level+1);
                }
                else
                {
                    string spacer = rightJustify("", level-2, ' ');
                    result ~= spacer ~ "* " ~ subItem.toMarkdown(level);
                }
            }
            return result;

        case ObjectType.Dict:
            auto dict = cast(Dict)item;
            string result;

            auto body = new String(dict.get!string("body", ""));
            dict.remove("body");
            auto dict2 = new Dict();
            /*
            Numeric dict keys will match a numeric sequence:
            */
            auto index = 0;
            foreach (key, value; dict)
            {
                if (index.to!string == key)
                {
                    key = "-";
                }
                dict2[key] = value;
                index++;
            }

            if (dict2.isNumeric)
            {
                result = dict2.asList.toMarkdown(level);
                result ~= body.toMarkdown;
            }
            else if (level == 1)
            {
                string hashes = rightJustify("", level, '#');
                foreach (key, value; dict)
                {
                    result ~= "\n" ~ hashes ~ " " ~ key ~ "\n\n";
                    result ~= value.toMarkdown(level+1);
                }
            }
            else
            {
                foreach (key, value; dict2)
                {
                    result ~= "* **" ~ key ~ "**: ";
                    result ~= value.toMarkdown(level);
                }
            }
            return result;

        default:
            if (level == 1)
            {
                return "\n" ~ item.toString ~ "\n";
            }
            else
            {
                return item.toString ~ "\n";
            }
    }
    assert(0);
}


void loadMarkdownCommands(CommandsMap commands)
{
    commands["to.markdown"] = function(string path, Input input, Output output)
    {
        foreach (item; input.popAll)
        {
            output.push(toMarkdown(item));
        }
        return ExitCode.Success;
    };
}
