module now.nodes.error;


import now.nodes;


CommandsMap errorCommands;


class Erro : Item
{
    int code = -1;
    string classe;
    string message;
    Item subject;
    Context context;

    this(string message, int code, string classe, Context context, Item subject=null)
    {
        this.subject = subject;
        this.message = message;
        this.code = code;
        this.classe = classe;
        this.type = ObjectType.Error;
        this.context = context;

        this.typeName = "error";
        this.commands = errorCommands;
    }

    // Conversions:
    override string toString()
    {
        string s = "Error " ~ to!string(code)
                   ~ ": " ~ message;
        if (classe)
        {
            s ~= " (" ~ classe ~ ")";
        }
        s ~= " on " ~ context.description;
        return s;
    }
}
