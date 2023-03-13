module now.nodes.vectors.commands;


import now.nodes;


static this ()
{
    byteVectorCommands["to.string"] = function (string path, Context context)
    {
        foreach (item; context.items)
        {
            auto vector = cast(ByteVector)item;
            string s = "";
            foreach (value; vector.values)
            {
                s ~= cast(char)value;
            }
            context.push(s);
        }
        return context;
    };
}
