module now.nodes.simpletemplate.methods;


import now;


static this()
{
    templateMethods["emit"] = function (Item object, string path, Input input, Output output)
    {
        auto tpl = cast(TemplateInstance)object;
        auto blockName = input.pop!string;

        Item[string] variables;
        // Variables coming from the current escopo:
        foreach (key, value; input.escopo)
        {
            // XXX: maybe we'll need to check for Sequences...?
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
                    tpl
                );
            }
        }

        tpl.emit(blockName, variables);
        output.push(tpl);
        return ExitCode.Success;
    };
    templateMethods["render"] = function (Item object, string name, Input input, Output output)
    {
        auto tpl = cast(TemplateInstance)object;
        output.push(tpl.render(input.escopo));
        return ExitCode.Success;
    };
}
