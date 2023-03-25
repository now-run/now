module now.nodes.path;


import now.nodes;


CommandsMap pathCommands;


class Path : Item
{
    string path;

    this(string path)
    {
        this.path = path;
        this.type = ObjectType.Path;
        this.typeName = "path";
        this.commands = pathCommands;
    }
    override string toString()
    {
        return this.path;
    }
}
