module now.json;


import std.json;


import now;


// if gdc:
version (GNU)
{
    alias JSONType = JSON_TYPE;
    alias JsonString = JSON_TYPE.STRING;
    alias JsonInteger = JSON_TYPE.INTEGER;
    alias JsonUInteger = JSON_TYPE.UINTEGER;
    alias JsonFloat = JSON_TYPE.FLOAT;
    alias JsonObject = JSON_TYPE.OBJECT;
    alias JsonArray = JSON_TYPE.ARRAY;
    alias JsonTrue = JSON_TYPE.TRUE;
    alias JsonFalse = JSON_TYPE.FALSE;
    alias JsonNull = JSON_TYPE.NULL;
}
else
{
    alias JsonString = JSONType.string;
    alias JsonInteger = JSONType.integer;
    alias JsonUInteger = JSONType.uinteger;
    alias JsonFloat = JSONType.float_;
    alias JsonObject = JSONType.object;
    alias JsonArray = JSONType.array;
    alias JsonTrue = JSONType.true_;
    alias JsonFalse = JSONType.false_;
    alias JsonNull = JSONType.null_;
}


Item JsonToItem(JSONValue v)
{
    switch (v.type)
    {
        case JsonString:
            return new String(v.str);
        case JsonInteger:
            return new Integer(v.integer);
        case JsonUInteger:
            return new Integer(v.uinteger);
        case JsonFloat:
            return new Float(v.floating);
        case JsonTrue:
            return new Boolean(true);
        case JsonFalse:
            return new Boolean(false);
        case JsonArray:
            return new List(
                v.array()
                    .map!(x => JsonToItem(x))
                    .array()
            );
        case JsonObject:
            auto dict = new Dict();
            auto obj = v.object();
            foreach (key; obj.byKey)
            {
                auto value = obj[key];
                dict[key] = JsonToItem(value);
            }
            return dict;
        default:
            if (v.isNull())
            {
                // XXX: should an Name("null") be used instead???
                return new String("<NULL>");
            }
            else
            {
                throw new Exception("Unknown type: " ~ v.type.to!string);
            }
    }
}

JSONValue ItemToJson(Item item, bool strict=false)
{
    switch (item.type)
    {
        case ObjectType.Boolean:
            return JSONValue(item.toBool());
        case ObjectType.Integer:
            return JSONValue(item.toLong());
        case ObjectType.Float:
            return JSONValue(item.toFloat());
        case ObjectType.Name:
        case ObjectType.String:
            auto s = item.toString();
            if (s == "<NULL>")
            {
                return JSONValue(null);
            }
            else
            {
                return JSONValue(item.toString());
            }
        case ObjectType.List:
            List list = cast(List)item;
            JSONValue[] values = list.items
                    .map!(x => ItemToJson(x, strict))
                    .array;
            return JSONValue(values);
        case ObjectType.Pair:
            auto pair = cast(Pair)item;
            auto key = pair.items[0].toString;
            auto value = pair.items[1];
            return JSONValue([ key: ItemToJson(value) ]);
        case ObjectType.Dict:
            Dict dict = cast(Dict)item;
            JSONValue[string] json;
            foreach (key; dict.values.byKey)
            {
                json[key] = ItemToJson(dict[key], strict);
            }
            return JSONValue(json);
        default:
            if (strict)
            {
                throw new Exception("Cannot decode type " ~ to!string(item.type));
            }
            return JSONValue(item.toString());
    }
}
