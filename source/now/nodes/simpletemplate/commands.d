module now.nodes.simpletemplate.commands;


import now.nodes;


static this()
{
    templateCommands["emit"] = function (string path, Context context)
    {
        auto tpl = context.pop!TemplateInstance();
        auto blockName = context.pop!string();

        Item[string] variables;
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

        tpl.emit(blockName, variables);
        return context;
    };
    templateCommands["render"] = function (string name, Context context)
    {
        auto tpl = context.pop!TemplateInstance();
        return context.push(tpl.render(context));
    };
}
