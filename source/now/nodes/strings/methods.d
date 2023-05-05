module now.nodes.strings.methods;

import std.array;
import std.conv : ConvException;
import std.file : dirEntries, SpanMode;
import std.regex : matchAll, matchFirst;
import std.string;
import std.algorithm.mutation : strip, stripLeft, stripRight;

import now;
import now.conv;


static this()
{
    stringMethods["eval"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > eval "set x 10"
        > print $x
        10
        */
        import now.grammar;

        auto code = input.pop!string();
        SubProgram subprogram;

        auto parser = new NowParser(code);
        // XXX: should we "translate" the eventual exception, here?
        subprogram = parser.consumeSubProgram();

        return subprogram.run(input.escopo, output, input.inputs);
    };


    stringMethods["get"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > "abcde" : get 2
        c
        */
        String target = input.pop!String();

        long i = input.pop!string().toLong();
        if (i < 0)
        {
            i = target.repr.length + i;
        }
        size_t index = cast(size_t)i;

        output.push(target.repr[index]);
        return ExitCode.Success;
    };
    stringMethods["."] = stringMethods["get"];

    stringMethods["slice"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > "abcde" : slice 1 3
        bc
        */
        String target = input.pop!String();

        auto s = input.pop!long;
        if (s < 0)
        {
            s = target.repr.length + s;
        }
        size_t start = cast(size_t)s;

        size_t end;
        auto item = input.pop!Item();
        if (item.toString() == "end")
        {
            end = target.repr.length;
        }
        else
        {
            long e = item.toLong();
            if (e < 0)
            {
                e = target.repr.length + e;
            }
            end = cast(size_t)e;
        }

        output.push(target.repr[start..end]);
        return ExitCode.Success;
    };

    stringMethods["length"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > $string : length
        */
        auto target = cast(String)object;
        output.push(target.repr.length);
        return ExitCode.Success;
    };
    stringMethods["split"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > "a/b/c" : split "/"
        (a , b , c)
        */
        auto target = (cast(String)object).toString;
        auto separator = input.pop!string;
        List l = new List(
            cast(Items)(target.split(separator)
                .map!(x => new String(x))
                .array)
        );
        output.push(l);
        return ExitCode.Success;
    };
    stringMethods["indent"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > "a" : indent 1
        "    a"
        */
        auto target = (cast(String)object).toString;
        auto level = input.pop!long();
        string spacer = rightJustify("", level * 4, ' ');
        output.push(new String(spacer ~ target));
        return ExitCode.Success;
    };
    stringMethods["strip"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > "abcxxxyy" : strip "yx"
        abc
        */
        auto target = (cast(String)object).toString;
        auto chars = input.pop!string();

        string s = target;
        foreach (c; chars)
        {
            s = s.strip(c);
        }
        output.push(s);
        return ExitCode.Success;
    };
    stringMethods["strip:left"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > "xabcxxxyy" : strip:left "yx"
        abcxxxyy
        */
        auto target = (cast(String)object).toString;
        auto chars = input.pop!string();

        string s = target;
        foreach (c; chars)
        {
            s = s.stripLeft(c);
        }
        output.push(s);
        return ExitCode.Success;
    };
    stringMethods["strip:right"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > "xabcxxxyy" : strip "yx"
        xabc
        */
        auto target = (cast(String)object).toString;
        auto chars = input.pop!string();

        string s = target;
        foreach (c; chars)
        {
            s = s.stripRight(c);
        }
        output.push(s);
        return ExitCode.Success;
    };
    stringMethods["find"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > "abc/def" : find "/"
        3
        */
        auto needle = (cast(String)object).toString;
        string haystack = input.pop!string;
        output.push(haystack.indexOf(needle));
        return ExitCode.Success;
    };
    stringMethods["matches"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > "http://example.com" : matches "^http:.\+"
        0
        */
        auto target = (cast(String)object).toString;
        string expression = input.pop!string();

        List l = new List([]);
        foreach(m; target.matchAll(expression))
        {
            l.items ~= new String(m.hit);
        }
        output.push(l);
        return ExitCode.Success;
    };
    stringMethods["match"] = function (Item object, string path, Input input, Output output)
    {
        /*
        # Returns the index of the FIRST match
        > "http://example.com" : match "^http:.\+"
        0
        */
        auto target = (cast(String)object).toString;
        string expression = input.pop!string();
        // XXX: is it really right?
        foreach(m; target.matchFirst(expression))
        {
            output.push(m);
        }
        return ExitCode.Success;
    };
    stringMethods["range"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > range "12345" -> 1 , 2 , 3 , 4 , 5
        */
        class StringRange : Item
        {
            string s;
            int currentIndex = 0;
            ulong _length;

            this(string s)
            {
                this.s = s;
                this._length = s.length;
            }
            override string toString()
            {
                return "StringRange";
            }
            override ExitCode next(Escopo escopo, Output output)
            {
                if (this.currentIndex >= this._length)
                {
                    return ExitCode.Break;
                }
                else
                {
                    auto chr = this.s[this.currentIndex++];
                    output.push(to!string(chr));
                    return ExitCode.Continue;
                }
            }
        }

        auto target = (cast(String)object).toString;
        output.push(new StringRange(target));
        return ExitCode.Success;
    };

    // Operators
    stringMethods["eq"] = function (Item object, string path, Input input, Output output)
    {
        /*
        > "abc" : eq "abc"
        true
        */

        auto target = (cast(String)object).toString;
        foreach (item; input.popAll)
        {
            output.push(item.toString() == target);
        }
        return ExitCode.Success;
    };
    stringMethods["=="] = stringMethods["eq"];
    stringMethods["neq"] = function (Item object, string path, Input input, Output output)
    {
        auto target = (cast(String)object).toString;
        foreach (item; input.popAll)
        {
            output.push(item.toString() == target);
        }
        return ExitCode.Success;
    };
    stringMethods["!="] = stringMethods["neq"];

    // Conversions
    stringMethods["to:integer"] = function (Item object, string path, Input input, Output output)
    {
        auto target = (cast(String)object).toString;
        output.push(target.toLong);
        return ExitCode.Success;
    };
    stringMethods["to:float"] = function (Item object, string path, Input input, Output output)
    {

        auto target = (cast(String)object).toString;
        output.push(target.to!float);
        return ExitCode.Success;
    };

    /*
    stringMethods["to:ascii"] = function (Item object, string path, Input input, Output output)
    {
        > "ab" : to:ascii
        (97 , 98)
        auto target = (cast(String)object).toString;
        auto items = target.toBytes()
            .map!(x => new IntegerAtom(x))
            .map!(x => cast(Item)x)
            .array;
        output.push(new List(items));
        return ExitCode.Success;
    };
    */
}
