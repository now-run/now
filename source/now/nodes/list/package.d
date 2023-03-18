module now.nodes.list;


import now.nodes;


CommandsMap listCommands;


class List : BaseList
{
    this()
    {
        super();
    }
    this(Items items)
    {
        super(items);
        this.commands = listCommands;
        this.type = ObjectType.List;
        this.typeName = "list";
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return "(" ~ to!string(this.items
            .map!(x => to!string(x))
            .join(" ")) ~ ")";
    }

    override Context evaluate(Context context)
    {
        return this.runAsInfixProgram(context);
    }

    ExecList infixProgram()
    {
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
                if (item.type == ObjectType.List)
                {
                    // Inner Lists also become InfixPrograms:
                    arguments ~= (cast(List)item).infixProgram();
                }
                else
                {
                    arguments ~= item;
                }
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
                new CommandCall(commandName, commandArgs)
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
                    return (cast(List)argument).infixProgram();
                }
                else
                {
                    /*
                    Example:
                        if $(true)
                    Becomes:
                        if ([push true])
                    */
                    // XXX: what???
                    auto commandCalls = [new CommandCall("stack.push", arguments)];
                    auto pipeline = new Pipeline(commandCalls);
                    auto subprogram = new SubProgram([pipeline]);
                    return new ExecList(subprogram);
                }
            }
            throw new Exception("execList cannot be null!");
        }
        return execList;
    }
    Context runAsInfixProgram(Context context)
    {
        return this.infixProgram().evaluate(context);
    }
}

class Pair : List
{
    this()
    {
        super();
        this.type = ObjectType.Pair;
        this.typeName = "pair";
    }
    this(Items items)
    {
        if (items.length != 2)
        {
            throw new InvalidException("Pairs can only have 2 items");
        }
        super(items);
        this.type = ObjectType.Pair;
        this.typeName = "pair";
    }
}
