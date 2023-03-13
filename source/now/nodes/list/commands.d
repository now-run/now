module now.nodes.list.commands;


import std.algorithm : map, sort;
import std.algorithm.searching : canFind;

import now.nodes;


// Commands:
static this()
{
    listCommands["set"] = function (string path, Context context)
    {
        string[] names;

        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` must receive at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto l1 = context.pop!List();
        auto l2 = context.pop!List();

        names = l1.items.map!(x => to!string(x)).array;

        Items values;
        // context = l2.forceEvaluate(context);
        values = l2.items;

        if (values.length < names.length)
        {
            auto msg = "Insuficient number of items in the second list";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        string lastName;
        foreach(name; names)
        {
            auto nextValue = values.front;
            if (!values.empty) values.popFront();

            context.escopo[name] = nextValue;
            lastName = name;
        }
        while(!values.empty)
        {
            // Everything else goes to the last name:
            auto seq = context.escopo[lastName];
            seq ~= values.front;
            values.popFront();
        }

        return context;
    };
    listCommands["as"] = listCommands["set"];

    listCommands["range"] = function (string path, Context context)
    {
        /*
        range (1 2 3 4 5)
        */
        class ItemsRange : Item
        {
            Items list;
            int currentIndex = 0;
            ulong _length;

            this(Items list)
            {
                this.list = list;
                this._length = list.length;
                this.type = ObjectType.Range;
                this.typeName = "list_range";
            }
            override string toString()
            {
                return "ItemsRange";
            }
            override Context next(Context context)
            {
                if (this.currentIndex >= this._length)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    auto item = this.list[this.currentIndex++];
                    context.push(item);
                    context.exitCode = ExitCode.Continue;
                }
                return context;
            }
        }

        List list = context.pop!List();
        return context.push(new ItemsRange(list.items));
    };
    listCommands["range.enumerate"] = function (string path, Context context)
    {
        /*
        range.enumerate (1 2 3 4 5)
        -> 0 1 , 1 2 , 2 3 , 3 4 , 4 5
        */
        class ItemsRangeEnumerate : Item
        {
            Items list;
            int currentIndex = 0;
            ulong _length;

            this(Items list)
            {
                this.list = list;
                this._length = list.length;
                this.type = ObjectType.Range;
                this.typeName = "list_range_enumerate";
            }
            override string toString()
            {
                return "ItemsRangeEnumerate";
            }
            override Context next(Context context)
            {
                if (this.currentIndex >= this._length)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    auto item = this.list[this.currentIndex];
                    context.push(item);
                    context.push(currentIndex);
                    this.currentIndex++;
                    context.exitCode = ExitCode.Continue;
                }
                return context;
            }
        }

        List list = context.pop!List();
        return context.push(new ItemsRangeEnumerate(list.items));
    };
    listCommands["get"] = function (string path, Context context)
    {
        List l = context.pop!List();

        if (context.size == 0) return context.push(l);

        // start:
        long s = context.pop().toInt();
        if (s < 0)
        {
            s = l.items.length + s;
        }
        size_t start = cast(size_t)s;

        if (context.size == 0)
        {
            return context.push(l.items[start]);
        }

        // end:
        long e = context.pop().toInt();
        if (e < 0)
        {
            e = l.items.length + e;
        }
        size_t end = cast(size_t)e;

        // slice:
        return context.push(new List(l.items[start..end]));
    };
    listCommands["."] = listCommands["get"];

    listCommands["infix"] = function (string path, Context context)
    {
        List list = context.pop!List();
        context = list.runAsInfixProgram(context);
        return context;
    };
    listCommands["expand"] = function (string path, Context context)
    {
        List list = context.pop!List();

        foreach (item; list.items.retro)
        {
            context.push(item);
        }

        return context;
    };
    listCommands["push"] = function (string path, Context context)
    {
        List list = context.pop!List();

        Items items = context.items;
        list.items ~= items;

        return context;
    };
    listCommands["pop"] = function (string path, Context context)
    {
        List list = context.pop!List();

        if (list.items.length == 0)
        {
            auto msg = "Cannot pop: the list is empty";
            return context.error(msg, ErrorCode.Empty, "");
        }

        auto lastItem = list.items[$-1];
        context.push(lastItem);
        list.items.popBack;

        return context;
    };
    listCommands["sort"] = function (string path, Context context)
    {
        class Comparator
        {
            Item item;
            Context context;
            this(Context context, Item item)
            {
                this.context = context;
                this.item = item;
            }

            override int opCmp(Object o)
            {
                Comparator other = cast(Comparator)o;

                context.push(other.item);
                context = item.runCommand("<", context);
                auto result = cast(BooleanAtom)context.pop();

                if (result.value)
                {
                    return -1;
                }
                else
                {
                    return 0;
                }
            }
        }

        List list = context.pop!List();

        Comparator[] comparators = list.items.map!(x => new Comparator(context, x)).array;
        Items sorted = comparators.sort.map!(x => x.item).array;
        return context.push(new List(sorted));
    };
    listCommands["reverse"] = function (string path, Context context)
    {
        List list = context.pop!List();
        Items reversed = list.items.retro.array;
        return context.push(new List(reversed));
    };
    listCommands["contains"] = function (string path, Context context)
    {
        if (context.size != 2)
        {
            auto msg = "`send` expects two arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        List list = context.pop!List();
        Item item = context.pop();

        return context.push(
            list.items
                .map!(x => to!string(x))
                .canFind(to!string(item))
        );
    };
    listCommands["length"] = function (string path, Context context)
    {
        auto l = context.pop!List();
        return context.push(l.items.length);
    };
    listCommands["eq"] = function (string path, Context context)
    {
        List rhs = context.pop!List();

        Item other = context.pop();
        if (other.type != ObjectType.List)
        {
            return context.push(false);
        }
        List lhs = cast(List)other;

        // XXX: we could compare item by item instead of relying on toString,
        // or at least call a `eq` for each value (beware of recursion, though).
        if (lhs.items.length != rhs.items.length)
        {
            return context.push(false);
        }
        return context.push(lhs.toString() == rhs.toString());
    };
    listCommands["=="] = listCommands["eq"];

    listCommands["neq"] = function (string path, Context context)
    {
        List rhs = context.pop!List();

        Item other = context.pop();
        if (other.type != ObjectType.List)
        {
            return context.push(true);
        }
        List lhs = cast(List)other;

        // XXX: we could compare item by item instead of relying on toString,
        // or at least call a `neq` for each value (beware of recursion, though).
        if (lhs.items.length != rhs.items.length)
        {
            return context.push(true);
        }
        return context.push(lhs.toString() != rhs.toString());
    };
    listCommands["!="] = listCommands["neq"];
}
