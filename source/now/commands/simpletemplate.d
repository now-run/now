module now.commands.simpletemplate;

import now;


void loadTemplateCommands(CommandsMap commands)
{
    commands["template"] = function(string path, Input input, Output output)
    {
        string name = input.pop!string;
        auto templates = input.escopo.document.data.getOrCreate!Dict("templates");
        auto tpl = templates.get!ExpandableBlock(name, null);
        if (tpl is null) {
            throw new NotFoundException(
                input.escopo,
                "Template '" ~ name ~ "' not found.",
                -1,
            );
        }

        Item[string] variables;

        // Variables coming from the current escopo:
        foreach (key, value; input.escopo)
        {
            variables[key] = value;
        }

        // Variables passed manually:
        foreach (item; input.popAll)
        {
            if (item.type == ObjectType.Pair)
            {
                auto pair = cast(Pair)item;
                auto key = pair.items[0].toString();
                auto value = pair.items[1];
                variables[key] = value;
            }
            else if (item.type == ObjectType.Dict)
            {
                auto dict = cast(Dict)item;
                foreach (key, value; dict.values)
                {
                    variables[key] = value;
                }
            }
            else
            {
                throw new SyntaxErrorException(
                    input.escopo,
                    "Invalid argument for " ~ path
                    ~ ": should be Pair or Dict",
                    -1,
                );
            }
        }
        output.push(new TemplateInstance(tpl, variables));
        return ExitCode.Success;
    };
}
