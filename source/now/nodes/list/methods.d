module now.nodes.list.methods;


import std.algorithm : map, sort;
import std.algorithm.searching : canFind;

import now;


// Methods:
static this()
{
    listMethods["get"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > list a b c : get 0
        a
        */
        List l = cast(List)object;

        // start:
        long i = input.pop!long();
        if (i < 0)
        {
            i = l.items.length + i;
        }
        size_t index = cast(size_t)i;

        output.push(l.items[index]);
        return ExitCode.Success;
    };
    listMethods["."] = listMethods["get"];

    listMethods["slice"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > list a b c d e : slice 0 2
        a b
        */
        List l = cast(List)object;
        auto s = input.pop!long();
        auto e = input.pop!long();
        auto start = cast(size_t)s;
        auto end = cast(size_t)e;

        output.push(new List(l.items[start..end]));
        return ExitCode.Success;
    };
    listMethods["to:sequence"] = function (Item object, string path, Input input, Output output)
    {
        List list = cast(List)object;
        output.push(new Sequence(list.items));
        return ExitCode.Success;
    };
    listMethods["push"] = function (Item object, string path, Input input, Output output)
    {
        List list = cast(List)object;
        list.items ~= input.popAll;
        return ExitCode.Success;
    };
    listMethods["pop"] = function (Item object, string path, Input input, Output output)
    {
        List list = cast(List)object;
        if (list.items.length == 0)
        {
            auto msg = "Cannot pop: the list is empty";
            throw new EmptyException(input.escopo, msg, -1, list);
        }

        auto lastItem = list.items.back;
        output.push(lastItem);
        list.items.popBack;

        return ExitCode.Success;
    };
    listMethods["sort"] = function (Item object, string path, Input input, Output output)
    {
        class Comparator
        {
            Item item;
            Escopo escopo;
            this(Escopo escopo, Item item)
            {
                this.escopo = escopo;
                this.item = item;
            }

            override int opCmp(Object o)
            {
                Comparator other = cast(Comparator)o;

                auto xinput = Input(
                    escopo,
                    [],
                    [other.item],
                    null,
                );
                Output xoutput;
                auto exitCode = item.runMethod("<", xinput, xoutput);
                if (xoutput.pop.toBool)
                {
                    return -1;
                }
                else
                {
                    return 0;
                }
            }
        }

        List list = cast(List)object;
        Comparator[] comparators = list.items.map!(x => new Comparator(input.escopo, x)).array;
        Items sorted = comparators.sort.map!(x => x.item).array;
        output.push(new List(sorted));
        return ExitCode.Success;
    };
    listMethods["reverse"] = function (Item object, string path, Input input, Output output)
    {
        List list = cast(List)object;
        Items reversed = list.items.retro.array;
        output.push(new List(reversed));
        return ExitCode.Success;
    };
    listMethods["contains"] = function (Item object, string path, Input input, Output output)
    {
        List list = cast(List)object;

        foreach (item; input.popAll)
        {
            output.push(
                list.items
                    .map!(x => to!string(x))
                    .canFind(to!string(item))
            );
        }
        return ExitCode.Success;
    };
    listMethods["length"] = function (Item object, string path, Input input, Output output)
    {
        List l = cast(List)object;
        output.push(l.items.length);
        return ExitCode.Success;
    };
    listMethods["eq"] = function (Item object, string path, Input input, Output output)
    {
        // XXX: is rhs and lhs inverted, here?
        List rhs = cast(List)object;
        Item other = input.pop!Item();
        if (other.type != ObjectType.List)
        {
            output.push(false);
            return ExitCode.Success;
        }
        List lhs = cast(List)other;

        // XXX: we could compare item by item instead of relying on toString,
        // or at least call a `eq` for each value (beware of recursion, though).
        if (lhs.items.length != rhs.items.length)
        {
            output.push(false);
            return ExitCode.Success;
        }
        output.push(lhs.toString() == rhs.toString());
        return ExitCode.Success;
    };
    listMethods["=="] = listMethods["eq"];

    listMethods["neq"] = function (Item object, string path, Input input, Output output)
    {
        List rhs = cast(List)object;
        Item other = input.pop!Item();
        if (other.type != ObjectType.List)
        {
            output.push(true);
            return ExitCode.Success;
        }
        List lhs = cast(List)other;

        // XXX: we could compare item by item instead of relying on toString,
        // or at least call a `neq` for each value (beware of recursion, though).
        if (lhs.items.length != rhs.items.length)
        {
            output.push(true);
            return ExitCode.Success;
        }
        output.push(lhs.toString() != rhs.toString());
        return ExitCode.Success;
    };
    listMethods["!="] = listMethods["neq"];

    // String-related:
    listMethods["join"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > (a , b , c) : join "/"
        a/b/c
        */
        List list = cast(List)object;
        string joiner = input.pop!string();
        output.push(
            new String(list.items.map!(x => to!string(x)).join(joiner))
        );
        return ExitCode.Success;
    };

    // Iterators:
    listMethods["foreach"] = function (Item object, string path, Input input, Output output)
    {
        throw new NotImplementedException(
            input.escopo,
            "Not implemented yet",
            -1
        );
    };
}
