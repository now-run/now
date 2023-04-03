module now.commands.json;


import std.array;
import std.json;

import now.nodes;
import now.commands;


// if gdc:
alias JSONType = JSON_TYPE;
alias JsonString = JSON_TYPE.STRING;
alias JsonInteger = JSON_TYPE.INTEGER;
alias JsonUInteger = JSON_TYPE.UINTEGER;
alias JsonFloat = JSON_TYPE.FLOAT;
alias JsonObject = JSON_TYPE.OBJECT;
alias JsonArray = JSON_TYPE.ARRAY;
alias JsonTrue = JSON_TYPE.TRUE;
alias JsonFalse = JSON_TYPE.FALSE;


Item JsonToItem(JSONValue v)
{
    switch (v.type)
    {
        case JsonString:
            return new String(v.str);
        case JsonInteger:
            return new IntegerAtom(v.integer);
        case JsonUInteger:
            return new IntegerAtom(v.uinteger);
        case JsonFloat:
            return new FloatAtom(v.floating);
        case JsonTrue:
            return new BooleanAtom(true);
        case JsonFalse:
            return new BooleanAtom(false);
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
            return JSONValue(item.toInt());
        case ObjectType.Float:
            return JSONValue(item.toFloat());
        case ObjectType.Atom:
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
        case ObjectType.Dict:
            Dict dict = cast(Dict)item;
            JSONValue[string] json;
            foreach (key; dict.values.byKey)
            {
                json[key] = ItemToJson(dict[key], strict);
            }
            return JSONValue(json);
        // case ObjectType.Vector:
        // item.typeName = {byte_vector|int_vector|long_vector|...}
        default:
            if (strict)
            {
                throw new Exception("Cannot decode type " ~ to!string(item.type));
            }
            return JSONValue(item.toString());
    }
}


void loadJsonCommands(CommandsMap commands)
{
    commands["json.decode"] = function (string path, Context context)
    {
        foreach (arg; context.items)
        {
            JSONValue json = parseJSON(arg.toString());
            auto object = JsonToItem(json);
            context.push(object);
        }
        return context;
    };
    commands["json.encode"] = function (string path, Context context)
    {
        foreach (arg; context.items)
        {
            auto json = ItemToJson(arg);
            context.push(json.toString());
        }
        return context;
    };
}
