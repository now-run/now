module now.commands.simpletemplate;

import now.nodes;


void loadTemplateCommands(CommandsMap commands)
{
    commands["template"] = function (string path, Context context)
    {
        string name = context.pop!string();
        auto templates = context.program.getOrCreate!Dict("templates");
        auto tpl = templates.get!Block(
            name,
            delegate (Dict d) {
                return cast(Block)null;
            }
        );
        if (tpl is null) {
            return context.error(
                "Template '" ~ name ~ "' not found.",
                ErrorCode.NotFound,
                ""
            );
        }

        Item[string] variables;
        /*
        Kinda weird, but the only place where using
        variables from the current context for
        the template is when instantiating,
        not when rendering.
        */

        // Variables coming from the current context:
        foreach (key, value; context.escopo.variables)
        {
            if (value.length)
            {
                variables[key] = value[0];
            }
        }

        // Variables passed manually:
        foreach (item; context.items)
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
                return context.error(
                    "Invalid argument for " ~ path
                    ~ ": should be Pair or Dict",
                    ErrorCode.InvalidArgument,
                    ""
                );
            }
        }
        return context.push(new TemplateInstance(tpl, variables));
    };
}
