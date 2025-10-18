module now.nodes.sqlite3.methods;

import now;


static this()
{
    none = new Name("null");

    sqlite3Methods["exec"] = function(Item object, string name, Input input, Output output)
    {
        auto db = cast(Sqlite3)object;
        foreach (item; input.popAll)
        {
            auto list = db.exec(item.toString);
            output.push(list);
        }
        return ExitCode.Success;
    };

}
