module now.nodes.dict;


import now.nodes;


CommandsMap dictCommands;


class Dict : Item
{
    Item[string] values;
    string[] order;
    bool isNumeric = true;

    this()
    {
        this.type = ObjectType.Dict;
        this.commands = dictCommands;
        this.typeName = "dict";
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
            order
                .map!(key => "(" ~ key ~ " = " ~ values[key].toString() ~ ")")
                .join(" ")
        );
        return s;
    }

    // ------------------
    // Operators
    Item opIndex(string k)
    {
        auto v = values.get(k, null);
        if (v is null)
        {
            throw new NotFoundException("key " ~ k ~ " not found");
        }
        return v;
    }
    // d[["a", "b", "c"]]
    Item opIndex(string[] keys)
    {
        auto pivot = this;
        foreach (key; keys)
        {
            auto nextDict = (key in pivot.values);
            if (nextDict is null)
            {
                return null;
            }
            else
            {
                pivot = cast(Dict)pivot[key];
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
        debug {stderr.writeln(" dict[", k, "] = ", to!string(v));}
        values[k] = v;

        // XXX: this seems kinda expensive:
        string[] newOrder;
        foreach (key; order)
        {
            if (key != k)
            {
                newOrder ~= key;
            }
        }
        newOrder ~= k;
        this.order = newOrder;
    }
    void opIndexAssign(Item v, string[] keys)
    {
        auto pivot = this;
        foreach (key; keys[0..$-1])
        {
            auto nextDictPtr = (key in pivot.values);
            if (nextDictPtr is null)
            {
                auto nextDict = new Dict();
                pivot[key] = nextDict;
                pivot = nextDict;
            }
            else
            {
                pivot = cast(Dict)(*nextDictPtr);
            }
        }
        pivot[keys[$-1]] = v;
    }

    template get(T)
    {
        T get(string key, T delegate(Dict) defaultValue)
        {
            auto valuePtr = (key in values);
            if (valuePtr !is null)
            {
                Item value = *valuePtr;
                return cast(T)value;
            }
            else
            {
                return defaultValue(this);
            }
        }
        T get(string[] keys, T delegate(Dict) defaultValue)
        {
            Dict pivot = this;
            foreach (key; keys[0..$-1])
            {
                auto pivotPtr = (key in pivot.values);
                if (pivotPtr !is null)
                {
                    auto item = *pivotPtr;
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
            return cast(T)(pivot[keys[$-1]]);
        }
    }

    template getOrCreate(T)
    {
        T getOrCreate(string key)
        {
            return this.get!T(
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
        auto valuePtr = (key in values);
        if (valuePtr !is null)
        {
            Item value = *valuePtr;
            callback(value);
        }
        else
        {
            neCallback();
        }
    }
    Item getOrNull(string key)
    {
        auto valuePtr = (key in values);
        if (valuePtr !is null)
        {
            Item value = *valuePtr;
            return value;
        }
        else
        {
            return null;
        }
    }

    Dict navigateTo(Items items, bool autoCreate=true)
    {
        auto pivot = this;
        foreach (item; items)
        {
            string key = item.toString();
            auto nextDict = (key in pivot.values);
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
                pivot = cast(Dict)pivot[key];
            }
        }
        return pivot;
    }

    void remove(string key)
    {
        values.remove(key);
        this.order = this.order.filter!(x => x != key).array;
    }

    override Context evaluate(Context context)
    {
        if (order.length > 0 && isNumeric)
        {
            return evaluateAsList(context);
        }
        else
        {
            return evaluateAsDict(context);
        }
    }

    Context evaluateAsDict(Context context)
    {
        return super.evaluate(context);
    }

    Context evaluateAsList(Context context)
    {
        return context.push(this.asList());
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

    override Context evaluateAsDict(Context context)
    {
        // We need to evaluate each value, here, since
        // they weren't evaluated normally before.
        auto d = new Dict();
        foreach (key, value; values)
        {
            auto newContext = context.next();
            newContext = value.evaluate(newContext);
            if (newContext.exitCode == ExitCode.Failure)
            {
                return newContext;
            }
            // XXX: but what if an item evaluates to a sequence?
            d[key] = newContext.pop();
            debug {stderr.writeln("  d[", key, "] = ", d[key]);}
        }
        debug {stderr.writeln("    Result:", d);}
        context.push(d);
        return context;
    }
    override Context evaluateAsList(Context context)
    {
        // We need to evaluate each value, here, since
        // they weren't evaluated normally before.
        Items items;
        foreach (key; this.order)
        {
            auto value = this.values[key];
            context = value.evaluate(context);
            if (context.exitCode == ExitCode.Failure)
            {
                return context;
            }
            items ~= context.pop();
        }
        context.push(new List(items));
        return context;
    }
}
