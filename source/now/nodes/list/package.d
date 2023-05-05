module now.nodes.list;


import now;


MethodsMap listMethods;


class List : Item
{
    Items items;

    this(Items items)
    {
        this.methods = listMethods;
        this.type = ObjectType.List;
        this.typeName = "list";
        this.items = items;
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return "(" ~ to!string(this.items
            .map!(x => to!string(x))
            .join(" , ")) ~ ")";
    }

    override Items evaluate(Escopo escopo)
    {
        log("- List.evaluate: ", this);

        string[] commandNames;
        Items arguments;

        foreach (index, item; items)
        {
            // 1 + 2 + 3 + 4 / 5 * 6
            // [+ 1 2]
            // [+ [+ 1 2] 3]
            // [+ [+ [+ 1 2] 3] 4]
            // Alternative:
            // [+ 1 2 3 4]
            // [/ [+ 1 2 3 4] 5]
            // [* [/ [+ 1 2 3 4] 5] 6]
            if (index % 2 == 0)
            {
                arguments ~= item;
            }
            else
            {
                commandNames ~= item.toString();
            }
        }

        auto argumentsIndex = 0;
        auto commandsIndex = 0;
        ExecList execList = null;

        while (argumentsIndex < arguments.length && commandsIndex < commandNames.length)
        {
            Items commandArgs = [arguments[argumentsIndex++]];
            Items commandKwArgs;
            string commandName = commandNames[commandsIndex++];

            while (argumentsIndex < arguments.length)
            {
                commandArgs ~= arguments[argumentsIndex++];
                if (commandsIndex < commandNames.length && commandNames[commandsIndex] == commandName)
                {
                    commandsIndex++;
                    continue;
                }
                else
                {
                    break;
                }
            }
            auto commandCalls = [
                new CommandCall(commandName, commandArgs, commandKwArgs)
            ];
            auto pipeline = new Pipeline(commandCalls);
            auto subprogram = new SubProgram([pipeline]);
            execList = new ExecList(subprogram);

            // This ExecList replaces the last seen argument:
            arguments[--argumentsIndex] = execList;
            // [0 1 2]
            //      ^
            // [0 [+ 0 1] 2]
            //       ^
        }

        if (execList is null)
        {
            if (arguments.length == 1)
            {
                auto argument = arguments[0];
                if (argument.type == ObjectType.List)
                {
                    return (cast(List)argument).evaluate(escopo);
                }
                else
                {
                    // TODO: check if this works fine:
                    return arguments;
                }
            }
            log("-- List.arguments: ", arguments);
            throw new Exception("execList cannot be null!");
        }
        log("-- List.execList: ", execList);
        return execList.evaluate(escopo);
    }
}

class Pair : List
{
    this(Items items)
    {
        if (items.length != 2)
        {
            throw new InvalidException(
                null,
                "Pairs can only have 2 items"
            );
        }
        super(items);
        this.type = ObjectType.Pair;
        this.typeName = "pair";
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return "(" ~ to!string(this.items
            .map!(x => to!string(x))
            .join(" = ")) ~ ")";
    }
}
