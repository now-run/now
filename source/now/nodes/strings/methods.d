module now.nodes.strings.methods;

import std.array;
import std.conv : ConvException;
import std.file : dirEntries, SpanMode;
import std.regex : ctRegex, matchAll, matchFirst, xplit = split, regexReplace = replace;
import std.string;
import std.algorithm.mutation : strip, stripLeft, stripRight;

import now;
import now.conv;


static this()
{
    stringMethods["eval"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > eval "set x 10"
        > print $x
        10
        */
        import now.grammar;

        auto code = (cast(String)object).toString;
        SubProgram subprogram;

        auto parser = new NowParser(code);
        // XXX: should we "translate" the eventual exception, here?
        subprogram = parser.consumeSubProgram();

        return subprogram.run(input.escopo, input.inputs, output);
    };

    stringMethods["get"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > "abcde" : get 2
        c
        */
        String target = cast(String)object;

        long i = input.pop!string().toLong();
        if (i < 0)
        {
            i = target.repr.length + i;
        }
        size_t index = cast(size_t)i;

        output.push(target.repr[index..index+1]);
        return ExitCode.Success;
    };
    stringMethods["."] = stringMethods["get"];

    stringMethods["to.lower"] = function(Item object, string path, Input input, Output output)
    {
        string target = (cast(String)object).toString;
        output.push(target.toLower);
        return ExitCode.Success;
    };
    stringMethods["to.upper"] = function(Item object, string path, Input input, Output output)
    {
        string target = (cast(String)object).toString;
        output.push(target.toUpper);
        return ExitCode.Success;
    };

    stringMethods["netstrings"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > "5:hello,5:world,blebs" : netstrings
        ("hello" , "world") blebs
        */
        string target = (cast(String)object).toString;
        Items items;

        while (target.length > 0)
        {
            log("netstring target: ", target);
            auto colonIndex = target.indexOf(':');
            log("- colonIndex: ", colonIndex);
            if (colonIndex == -1)
            {
                break;
            }
            auto size = target[0..colonIndex].to!int;
            auto start = colonIndex + 1;
            auto end = start + size;
            log("- size, start, end: ", size, " ", start, " ", end);
            if (target[end] != ',')
            {
                throw new InvalidArgumentsException(
                    input.escopo,
                    "Netstrings must end with a comma.",
                    -1,
                    object
                );
            }
            auto substring = target[start..end];
            log("- substring: ", substring);
            items ~= new String(substring);
            target = target[end+1..$];
        }

        output.push(
            new List([
                new List(items),
                new String(target)]
            )
        );
        return ExitCode.Success;
    };
    stringMethods["c.strings"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > "key\0value\0key2\0value2\0\k3\0v3" : c.strings
        (key value key2 value2 k3 v3)
        */
        string target = (cast(String)object).toString;

        Items items;

        while (target.length > 0)
        {
            auto end = target.indexOf('\0');
            if (end == -1)
            {
                log("c.strings: can't find NULL in the string: ", target);
                break;
            }
            auto substring = target[0..end];
            items ~= new String(substring);
            log("c.strings end: ", end);
            log("- substring: ", substring);
            auto start = end + 1;
            log("- start: ", start);
            target = target[start..$];
        }
        output.push(new List(items));
        return ExitCode.Success;
    };

    stringMethods["slice"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > "abcde" : slice 1 3
        bc
        */
        String target = cast(String)object;

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

    stringMethods["length"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > $string : length
        */
        auto target = cast(String)object;
        output.push(target.repr.length);
        return ExitCode.Success;
    };
    stringMethods["split"] = function(Item object, string path, Input input, Output output)
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
    stringMethods["indent"] = function(Item object, string path, Input input, Output output)
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
    stringMethods["strip"] = function(Item object, string path, Input input, Output output)
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
    stringMethods["strip.left"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > "xabcxxxyy" : strip.left "yx"
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
    stringMethods["strip.right"] = function(Item object, string path, Input input, Output output)
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
    stringMethods["find"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > o "abc/def" | :: find "/"
        3
        */
        auto haystack = (cast(String)object).toString;
        foreach (needleItem; input.popAll)
        {
            string needle = needleItem.toString;
            output.push(haystack.indexOf(needle));
        }
        return ExitCode.Success;
    };
    stringMethods["matches"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > "http://example.com" : matches "^http:.\+"
        0
        */
        auto target = (cast(String)object).toString;
        string expression = input.pop!string();

        List l = new List([]);
        foreach (m; target.matchAll(expression))
        {
            l.items ~= new String(m.hit);
        }
        output.push(l);
        return ExitCode.Success;
    };
    stringMethods["match"] = function(Item object, string path, Input input, Output output)
    {
        /*
        # Returns the FIRST match
        > "http://example.com" | :: match "^//.\+"
        //example.com
        */
        auto target = (cast(String)object).toString;

        foreach (expression; input.popAll)
        {
            foreach (m; target.matchFirst(expression.toString))
            {
                output.push(m);
            }
        }
        return ExitCode.Success;
    };
    stringMethods["contains"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > "http://example.com" | :: contains "^//.\+"
        true
        */
        auto target = (cast(String)object).toString;

        foreach (expression; input.popAll)
        {
            auto answer = false;
            foreach (m; target.matchFirst(expression.toString))
            {
                answer = true;
                break;
            }
            output.push(answer);
        }
        return ExitCode.Success;
    };
    stringMethods["replace"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > o "http://example.com" : replace "http" "ftp"
        "ftp://example.com"
        */
        auto s = (cast(String)object).toString;

        string search, replacement;

        while (true)
        {
            try
            {
                search = input.pop!string();
                replacement = input.pop!string();
            }
            catch (EmptyException)
            {
                break;
            }

            s = s.replace(search, replacement);
        }
        output.push(s);
        return ExitCode.Success;
    };

    stringMethods["slug"] = function(Item object, string path, Input input, Output output)
    {
        /*
        o "a?bc/dEf^g" | :: slug
        > a-bc-def-g
        */
        auto s = (cast(String)object).toString;
        auto result = s.toLower.regexReplace(ctRegex!(`[^a-z\d]+`, "g"), "-");
        output.push(result);

        return ExitCode.Success;
    };

    stringMethods["validate_email"] = function(Item object, string path, Input input, Output output)
    {
        /*
        o "x@x" | :: validate_email
        > true
        */
        auto s = (cast(String)object).toString;
        if (s.split("@").length != 2)
        {
            output.push(false);
        }
        else
        {
            auto result = s.matchFirst(ctRegex!(`.+@[^@]+$`));
            output.push(cast(bool)result);
        }

        return ExitCode.Success;
    };



    stringMethods["kebab_case"] = function(Item object, string path, Input input, Output output)
    {
        auto s = (cast(String)object).toString;

        static auto regexes = [
            // SetURLParams -> Set-URL-Params
            ctRegex!(`(.)([A-Z][a-z]+)`, "g"),
            // AlfaBetaGama -> Alfa-Beta-Gama
            ctRegex!(`([a-z0-9])([A-Z])`, "g"),
        ];
        foreach (re; regexes)
        {
            s = s.regexReplace(re, `$1-$2`);
        }
        // a_b_c -> a-b-c
        s = s.regexReplace(ctRegex!(`[_ ]+`, "g"), `-`);
        s = s.regexReplace(ctRegex!(`-+`, "g"), `-`);

        output.push(s.toLower);
        return ExitCode.Success;
    };
    stringMethods["snake_case"] = function(Item object, string path, Input input, Output output)
    {
        auto s = (cast(String)object).toString;

        static auto regexes = [
            // SetURLParams -> Set_URL_Params
            ctRegex!(`(.)([A-Z][a-z]+)`, "g"),
            // AlfaBetaGama -> Alfa_Beta_Gama
            ctRegex!(`([a-z0-9])([A-Z])`, "g"),
        ];

        foreach (re; regexes)
        {
            s = s.regexReplace(re, `$1_$2`);
        }

        // a-b-c -> a_b_c
        s = s.regexReplace(ctRegex!(`[- ]+`, "g"), `_`);
        s = s.regexReplace(ctRegex!(`_+`, "g"), `_`);

        output.push(s.toLower);
        return ExitCode.Success;
    };
    stringMethods["camel_case"] = function(Item object, string path, Input input, Output output)
    {
        auto s = (cast(String)object).toString;
        s = s.xplit(ctRegex!(`[_\- ]+`, "g"))
                .map!(x => x[0].to!string.capitalize ~ x[1..$])
                .join("");
        output.push(s);
        return ExitCode.Success;
    };
    stringMethods["capitalize"] = function(Item object, string path, Input input, Output output)
    {
        auto s = (cast(String)object).toString;
        output.push(s.capitalize);
        return ExitCode.Success;
    };
    stringMethods["range"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > o "12345" : range | collect
        (1 , 2 , 3 , 4 , 5)
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
    stringMethods["eq"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > "abc" : eq "abc"
        true
        */

        auto target = (cast(String)object).toString;
        foreach (item; input.popAll)
        {
            log("- eq ", target, " ", item, "?");
            output.push(item.toString() == target);
        }
        return ExitCode.Success;
    };
    stringMethods["=="] = stringMethods["eq"];
    stringMethods["neq"] = function(Item object, string path, Input input, Output output)
    {
        auto target = (cast(String)object).toString;
        foreach (item; input.popAll)
        {
            log("- neq ", target, " ", item, "?");
            output.push(item.toString() != target);
        }
        return ExitCode.Success;
    };
    stringMethods["!="] = stringMethods["neq"];
    stringMethods["gt"] = function(Item object, string path, Input input, Output output)
    {
        auto target = (cast(String)object).toString;
        foreach (item; input.popAll)
        {
            output.push(cmp!"a > b"(item.toString(), target) == 1);
        }
        return ExitCode.Success;
    };
    stringMethods["gte"] = function(Item object, string path, Input input, Output output)
    {
        auto target = (cast(String)object).toString;
        foreach (item; input.popAll)
        {
            output.push(cmp!"a > b"(item.toString(), target) != -1);
        }
        return ExitCode.Success;
    };
    stringMethods["lt"] = function(Item object, string path, Input input, Output output)
    {
        auto target = (cast(String)object).toString;
        foreach (item; input.popAll)
        {
            output.push(cmp!"a < b"(item.toString(), target) == 1);
        }
        return ExitCode.Success;
    };
    stringMethods["lte"] = function(Item object, string path, Input input, Output output)
    {
        auto target = (cast(String)object).toString;
        foreach (item; input.popAll)
        {
            output.push(cmp!"a < b"(item.toString(), target) != -1);
        }
        return ExitCode.Success;
    };

    stringMethods["to.bytes"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > "ab" | :: to.bytes
        (97 , 98)
        */
        auto target = cast(String)object;
        auto items = cast(Items)(
            target.toBytes()
                .map!(x => new Integer(x))
                .array
        );
        output.push(new List(items));
        return ExitCode.Success;
    };
    stringMethods["reverse"] = function(Item object, string path, Input input, Output output)
    {
        /*
        > "abc" | :: reverse
        "cba"
        */
        auto target = cast(String)object;
        auto reversed = target.toString.retro.array.to!string;
        output.push(reversed);
        return ExitCode.Success;
    };
}
