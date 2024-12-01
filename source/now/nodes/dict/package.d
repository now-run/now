module now.nodes.dict;

import std.algorithm.mutation : reverse;
import std.algorithm.searching : countUntil;
import now;


MethodsMap dictMethods;


class Dict : Item
{
    Item[string] values;
    string[] orderedKeys;
    bool needsReordering = true;
    bool isNumeric = true;

    this()
    {
        this.type = ObjectType.Dict;
        this.typeName = "dict";
        this.methods = dictMethods;
    }
    this(Item[string] values)
    {
        this();
        foreach (key, value; values)
        {
            this[key] = value;
        }
    }

    // ------------------
    // Conversions
    override string toString()
    {
        string s = "dict " ~ to!string(
            this.asPairs
                .map!(key => key.toString())
                .join(" ")
        );
        return s;
    }
    Pair[] asPairs()
    {
        Pair[] pairs;

        foreach (key; order)
        {
            auto value = values[key];
            pairs ~= new Pair([new String(key), value]);
        }

        return pairs;
    }
    override Item range()
    {
        return new ItemsRange(cast(Items)asPairs);
    }

    // ------------------
    // Ordering
    @property
    string[] order()
    {
        if (needsReordering)
        {
            // XXX: maybe use a fixed-size array, here:
            log("dict.orderedKeys: ", orderedKeys);
            string[] newOrder;
            foreach (x; orderedKeys.reverse.array)
            {
                if (newOrder.countUntil(x) > -1)
                {
                    continue;
                }

                auto ptr = (x in values);
                if (ptr !is null)
                {
                    newOrder ~= x;
                }
            }
            this.orderedKeys = newOrder.reverse.array;
            log(" --> ", orderedKeys);
            this.needsReordering = false;
        }
        return orderedKeys;
    }
    // ------------------
    // Operators
    Item opIndex(string key)
    {
        auto value = values.get(key, null);
        if (value is null)
        {
            throw new NotFoundException(
                null,
                "key " ~ key ~ " not found"
            );
        }
        return value;
    }
    // d[["a", "b", "c"]]
    Item opIndex(string[] keys)
    {
        auto pivot = this;
        foreach (key; keys)
        {
            auto nextDict = pivot.get(key, null);
            if (nextDict is null)
            {
                return null;
            }
            else
            {
                pivot = cast(Dict)nextDict;
            }
        }
        return pivot;
    }
    void opIndexAssign(Item v, string k)
    {
        if (k == "-")
        {
            k = this.order.length.to!string;
        }
        else
        {
            isNumeric = false;
        }

        values[k] = v;
        this.orderedKeys ~= k;
        this.needsReordering = true;
    }
    void opIndexAssign(Item v, string[] keys)
    {
        auto pivot = this;
        foreach (key; keys[0..$-1])
        {
            auto d = pivot.get(key, null);
            if (d is null)
            {
                auto nextDict = new Dict();
                pivot[key] = nextDict;
                pivot = nextDict;
            }
            else
            {
                pivot = cast(Dict)d;
            }
        }
        pivot[keys[$-1]] = v;
    }
    void opIndexAssign(Items items, string k)
    {
        this[k] = new Sequence(items);
    }

    ulong length()
    {
        return values.length;
    }

    // --------------------------------------
    // "getters":
    Item get(string key, Item defaultValue)
    {
        Item value = values.get(key, null);
        if (value is null)
        {
            return defaultValue;
        }
        else
        {
            return value;
        }
    }
    template get(T)
    {
        T get(string key)
        {
            Item value = this[key];
            static if (__traits(hasMember, T, "typeName"))
            {
                return cast(T)value;
            }
            else
            {
                return __traits(getMember, value, "to" ~ capitalize(T.stringof))();
            }
        }
        T get(string key, T defaultValue)
        {
            Item value = get(key, null);

            if (value !is null)
            {
                static if (__traits(hasMember, T, "typeName"))
                {
                    return cast(T)value;
                }
                else
                {
                    return __traits(getMember, value, "to" ~ capitalize(T.stringof))();
                }
            }
            else
            {
                return defaultValue;
            }
        }
        T get(string[] keys, T defaultValue)
        {
            Dict pivot = this;
            foreach (key; keys[0..$-1])
            {
                auto item = pivot.get(key, null);
                if (item !is null)
                {
                    if (item.type != ObjectType.Dict)
                    {
                        throw new Exception(
                            "Cannot index "
                            ~ item.type.to!string
                            ~ " (" ~ item.toString() ~ ")"
                            ~ " on key " ~ key
                        );
                    }
                    pivot = cast(Dict)item;
                }
                else
                {
                    return defaultValue;
                }
            }
            static if (__traits(hasMember, T, "typeName"))
            {
                return cast(T)(pivot[keys[$-1]]);
            }
            else
            {
                return __traits(getMember, pivot[keys[$-1]], "to" ~ capitalize(T.stringof))();
            }
        }
    }
    template getOr(T)
    {
        T getOr(string key, T delegate(Dict) defaultValue)
        {
            T value = get!T(key, null);
            if (value !is null)
            {
                return value;
            }
            else
            {
                return defaultValue(this);
            }
        }
        T getOr(string[] keys, T delegate(Dict) defaultValue)
        {
            Dict pivot = this;
            foreach (key; keys[0..$-1])
            {
                auto item = pivot.get(key, null);
                if (pivot !is null)
                {
                    if (item.type != ObjectType.Dict)
                    {
                        throw new Exception(
                            "Cannot index "
                            ~ item.type.to!string
                            ~ " (" ~ item.toString() ~ ")"
                            ~ " on key " ~ key
                        );
                    }
                    pivot = cast(Dict)item;
                }
                else
                {
                    return defaultValue(this);
                }
            }
            static if (__traits(hasMember, T, "typeName"))
            {
                return cast(T)(pivot[keys[$-1]]);
            }
            else
            {
                return (pivot[keys[$-1]]).to!T;
            }
        }
    }

    template getOrCreate(T)
    {
        T getOrCreate(string key)
        {
            return this.getOr!T(
                key,
                delegate (Dict d) {
                    auto newItem = new T();
                    d[key] = newItem;
                    return newItem;
                }
            );
        }
        T getOrCreate(string[] keys)
        {
            Dict pivot = this;
            foreach (key; keys[0..$-1])
            {
                pivot = pivot.getOrCreate!Dict(key);
            }
            return cast(T)(pivot.getOrCreate!T(keys[$-1]));
        }
    }

    void on(string key, void delegate(Item) callback, void delegate() neCallback)
    {
        auto value = get(key, null);
        if (value !is null)
        {
            callback(value);
        }
        else
        {
            neCallback();
        }
    }

    Dict navigateTo(Items items, bool autoCreate=true)
    {
        auto pivot = this;
        foreach (item; items)
        {
            string key = item.toString();
            auto nextDict = pivot.get(key, null);
            if (nextDict is null)
            {
                if (autoCreate)
                {
                    auto d = new Dict();
                    pivot[key] = d;
                    pivot = d;
                }
                else
                {
                    return null;
                }
            }
            else
            {
                pivot = cast(Dict)nextDict;
            }
        }
        return pivot;
    }

    void remove(string key)
    {
        values.remove(key);
        this.needsReordering = true;
    }

    // Operator for `foreach (key, value; dict) {...}`
    // TODO test it!
    int opApply(scope int delegate(ref string, ref Item) dg)
    {
        foreach (key; this.order)
        {
            auto value = this.values[key];
            int result = dg(key, value);
            if (result) return result;
        }
        return 0;
    }

    void update(Dict other)
    {
        foreach (k, v; other)
        {
            this[k] = v;
        }
    }

    override Items evaluate(Escopo escopo)
    {
        if (order.length > 0 && isNumeric)
        {
            return evaluateAsList(escopo);
        }
        else
        {
            return evaluateAsDict(escopo);
        }
    }

    Items evaluateAsDict(Escopo escopo)
    {
        return super.evaluate(escopo);
    }

    Items evaluateAsList(Escopo escopo)
    {
        return [this.asList()];
    }

    List asList()
    {
        Items items;
        foreach (key; this.order)
        {
            items ~= this.values[key];
        }
        return new List(items);
    }
}


class SectionDict : Dict
{
    this()
    {
        super();
        this.typeName = "section_dict";
    }
    this(Item[string] values)
    {
        super(values);
    }

    override Items evaluateAsDict(Escopo escopo)
    {
        // We need to evaluate each value, here, since
        // they weren't evaluated normally before.
        auto d = new Dict();
        foreach (key, value; values)
        {
            // XXX: if more than one Item is returned, it's totally ignored...
            d[key] = value.evaluate(escopo).front;
        }
        return [d];
    }
    override Items evaluateAsList(Escopo escopo)
    {
        // We need to evaluate each value, here, since
        // they weren't evaluated normally before.
        Items items;
        foreach (key; this.order)
        {
            auto value = this.values[key];
            // TODO: when output.push(Sequence), expand all Items in it!
            items ~= value.evaluate(escopo);
        }
        return [new List(items)];
    }
}
