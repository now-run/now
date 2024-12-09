module now.nodes.list.methods;


import std.algorithm : map, sort;
import std.algorithm.searching : canFind;
import std.conv : toChars;
import std.range : chunks;

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

    listMethods["as"] = function (Item object, string path, Input input, Output output)
    {
        List l = cast(List)object;
        foreach (index, varName; input.popAll)
        {
            input.escopo[varName.toString] = l.items[index];
        }
        return ExitCode.Success;
    };


    listMethods["first"] = function (Item object, string path, Input input, Output output)
    {
        List l = cast(List)object;
        if (l.items.length == 0)
        {
            throw new EmptyException(
                input.escopo,
                "List is empty",
                -1,
                l
            );
        }
        output.push(l.items[0]);
        return ExitCode.Success;
    };
    listMethods["last"] = function (Item object, string path, Input input, Output output)
    {
        List l = cast(List)object;
        if (l.items.length == 0)
        {
            throw new EmptyException(
                input.escopo,
                "List is empty",
                -1,
                l
            );
        }
        output.push(l.items[$ - 1]);
        return ExitCode.Success;
    };
    listMethods["truncate"] = function (Item object, string path, Input input, Output output)
    {
        List l = cast(List)object;
        l.items = [];
        return ExitCode.Success;
    };
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
    listMethods["to.sequence"] = function (Item object, string path, Input input, Output output)
    {
        List list = cast(List)object;
        output.push(list.items);
        return ExitCode.Success;
    };
    listMethods["push"] = function (Item object, string path, Input input, Output output)
    {
        List list = cast(List)object;
        list.items ~= input.popAll;
        output.push(list);
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
    listMethods["pop.front"] = function (Item object, string path, Input input, Output output)
    {
        List list = cast(List)object;
        if (list.items.length == 0)
        {
            auto msg = "Cannot pop: the list is empty";
            throw new EmptyException(input.escopo, msg, -1, list);
        }

        auto firstItem = list.items.front;
        output.push(firstItem);
        list.items.popFront;

        return ExitCode.Success;
    };
    listMethods["to.pairs"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > list a 1 b 2 c 3 : to.pairs
        (a = 1) (b = 2) (c = 3)
        */
        List l = cast(List)object;
        if (l.items.length % 2 != 0)
        {
            throw new InvalidArgumentsException(
                input.escopo,
                "List has odd number of items.",
                -1,
                l
            );
        }

        foreach (pair; l.items.chunks(2))
        {
            output.push(new Pair(pair));
        }

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
                auto xoutput = new Output;
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
        > o (a , b , c) | :: join "/"
        a/b/c
        */
        List list = cast(List)object;
        string joiner = input.pop!string("");
        output.push(
            new String(list.items.map!(x => to!string(x)).join(joiner))
        );
        return ExitCode.Success;
    };
    listMethods["to.ascii"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > o (97 , 98 , 99) | :: to.ascii
        "abc"
        */
        List list = cast(List)object;
        string joiner = input.pop!string("");
        output.push(new String(
            list
                .items
                .map!(x => ((cast(char)(x.toLong)).to!string))
                .join(joiner)
        ));
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
