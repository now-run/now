module now.grammar;


import std.algorithm : among, canFind;
import std.math : pow;

import now.nodes;
import now.parser;


const PIPE = '|';
const METHOD_SELECTOR = ':';

// Integers units:
uint[char] units;

static this()
{
    units['K'] = 1;
    units['M'] = 2;
    units['G'] = 3;
}


class NowParser : Parser
{
    this(string code)
    {
        super(code);
    }
    Document run()
    {
        try
        {
            return consumeDocument();
        }
        catch(Exception ex)
        {
            throw new Exception(
                "Error at line " ~
                line.to!string ~
                ", column " ~
                col.to!string ~
                ": " ~ ex.to!string
            );
        }
    }

    Document consumeDocument()
    {
        /*
        hashbang line...
        */
        log("% consumeDocument");
        while (currentChar == '#')
        {
            consumeLine();
            consumeWhitespaces();
        }

        auto title = consumeSectionHeaderAsString();
        log("% title=", title);
        auto metadataSection = consumeSection();
        log("% metadataSection=", metadataSection);

        auto description = metadataSection.get!string("body");
        log("% description=", description);
        auto metadata = metadataSection;
        log("% metadata=", metadata);
        // TESTE:
        auto x = cast(Dict)metadata;
        log("% x=", x);
        auto document = new Document(title, description, cast(Dict)metadata);

        consumeWhitespaces();

        // Now read the other sections:
        log("% Parsing remaining sections...");
        while (!eof)
        {
            auto section_path = consumeSectionHeader();
            log("%% section_path: ", section_path);
            if (section_path[0].toString()[0] == '#')
            {
                // Consume the section ignoring it completely
                while (true)
                {
                    auto c = consumeChar();
                    if (c == EOL)
                    {
                        if (currentChar == '[')
                        {
                            break;
                        }
                    }
                }
                continue;
            }
            auto subDict = document.data.navigateTo(section_path[0..$-1]);
            log("%% subDict: ", subDict);
            auto key = section_path[$-1].toString();
            auto value = consumeSection();
            log("%% key: ", key);

            auto currentValue = subDict.get(key, null);
            log("%% currentValue: ", currentValue);
            if (currentValue is null)
            {
                subDict[key] = value;
            }
            else
            {
                assert (currentValue.type == ObjectType.Dict);
                auto existentDict = cast(Dict)currentValue;
                existentDict.update(value);
            }
            consumeWhitespaces();
        }

        return document;
    }
    string consumeSectionHeaderAsString()
    {
        auto opener = consumeChar();
        if (opener != '[')
        {
            throw new Exception(
                "Invalid syntax: expecting section header"
            );
        }
        string title = consume_string(']');
        auto closer = consumeChar();
        if (closer != ']')
        {
            throw new Exception(
                "Invalid section header ("
                ~ closer.to!string
                ~ ")"
            );
        }
        return title;
    }
    Items consumeSectionHeader()
    {
        Items items;

        auto opener = consumeChar();
        if (opener != '[')
        {
            throw new Exception(
                "Invalid syntax: expecting section header"
            );
        }

        string token;
        while (currentChar != ']')
        {
            auto c = consumeChar();
            if (c == '/')
            {
                if (token.length == 0)
                {
                    throw new Exception(
                        "Invalid section header at line "
                        ~ line.to!string
                    );
                }
                items ~= new String(token);
                token = "";
            }
            else
            {
                token ~= c;
            }
        }
        if (token.length)
        {
            items ~= new String(token);
        }

        auto closer = consumeChar();
        auto newline = consumeChar();

       return items;
    }
    SectionDict consumeSection()
    {
        // No whitespaces after the header!

        /*
        We can have comment lines immediately
        after the section header and immediately
        before the section dict:
        */
        while (currentChar == '#')
        {
            consumeLine();
        }

        // key simple_value
        // key { document_dict }
        auto dict = consumeSectionDict();

        consumeWhitespaces();

        // After a newline, it's
        // i) another section header or
        // ii) a section body.
        string body = "";
        if (currentChar != '[')
        {
            while (!eof)
            {
                if (isEndOfLine)
                {
                    // newline:
                    auto nl = consumeChar();

                    // "\n[" is a new section!
                    if (currentChar == '[')
                    {
                        break;
                    }
                    else
                    {
                        body ~= nl;
                    }
                }
                else
                {
                    body ~= consumeChar();
                }
            }
        }
        if (body.length)
        {
            dict["body"] = new String(body);
        }

        return dict;
    }
    SectionDict consumeSectionDict()
    {
        /*
        section dict:
        key value EOL
        key value EOL
        key value EOL
        EOL  <-- this marks the end.
        */
        auto dict = new SectionDict();

        while (currentChar != EOL)
        {
            // Dict content may be indented...
            consumeWhitespaces();

            if (currentChar == '}')
            {
                consumeChar(); // }
                break;
            }

            auto key = consumeAtom();

            consumeWhitespace();

            Item value;
            if (currentChar == '{')
            {
                consumeChar();
                consumeWhitespaces();
                auto valueDict = consumeSectionDict();
                if (valueDict.order.length && valueDict.isNumeric)
                {
                    // XXX: is it correct???
                    value = valueDict.asList();
                }
                else
                {
                    value = valueDict;
                }
            }
            else
            {
                value = consumeItem();
            }
            dict[key.toString()] = value;

            auto newline = consumeChar();
            if (newline != EOL)
            {
                throw new Exception(
                    "Expecting newline after section dict entry, found `"
                    ~ newline
                    ~ "`"
                );
            }
        }

        return dict;
    }

    Item consumeInlineSectionDict()
    {
        /*
             \ /
              v
        set d <{
            key1 value1
            key2 value2
        }>
        */
        auto inlineOpener = consumeChar();
        if (currentChar != '{')
        {
            // Ooops! Go back one char...
            index --;
            // It's probably an operator:
            return consumeAtom();
        }
        // Consume the opener:
        consumeChar();

        consumeWhitespaces();
        auto dict = consumeSectionDict();
        // XXX: this consumeSectionDict function is kinda weird...
        auto inlineCloser = consumeChar();

        return dict;
    }

    // ---------------------------
    // Nodes
    // ---------------------------

    SubProgram consumeSubProgram()
    {
        Pipeline[] pipelines;

        consumeWhitespaces();

        while(!isBlockCloser)
        {
            pipelines ~= consumePipeline();

            /*
            Pipelines can't begin with '['. If that's
            the case, we just found a new section header.
            */
            consumeWhitespaces();
            if (currentChar == '[')
            {
                break;
            }
        }

        return new SubProgram(pipelines);
    }

    Pipeline consumePipeline()
    {
        CommandCall[] commandCalls;

        consumeWhitespaces();

        while (!isEndOfLine && !isBlockCloser)
        {
            auto commandCall = consumeCommandCall();
            commandCalls ~= commandCall;

            if (currentChar == PIPE)
            {
                consumeChar();
                consumeSpace();
            }
            else if (currentChar == METHOD_SELECTOR)
            {
                consumeChar();
                consumeSpace();
                // Mark the command as a target:
                commandCall.isTarget = true;
            }
            else
            {
                break;
            }
        }

        if (isEndOfLine && !eof) consumeChar();
        return new Pipeline(commandCalls, line);
    }

    CommandCall consumeCommandCall()
    {
        // inline transform/foreach:
        if (currentChar == '{')
        {
            CommandCall nextCall = foreachInline();
            if (!isEndOfLine)
            {
                // Whops! It's not a foreach.inline, but a transform.inline!
                nextCall.name = "transform.inline";
                consumeWhitespaces();
            }
            return nextCall;
        }

        /*
        > ls /opt -- (size_format = h)
            (args -- kwargs)
        */

        // TODO: allow using References, like:
        // > $dict | get key | print
        Name commandName = cast(Name)consumeAtom();
        Items args;
        Items kwargs;

        bool readingKwArgs = false;

        // That is: if the command HAS any argument:
        while (true)
        {
            if (currentChar == EOL)
            {
                consumeChar();
                consumeWhitespaces();
                if (currentChar == '.')
                {
                    consumeChar();
                    // consumeSpace();
                }
                else
                {
                    break;
                }
            }

            if (currentChar == SPACE)
            {
                consumeSpace();
                if (currentChar.among!('}', ']', ')', '>', PIPE, METHOD_SELECTOR))
                {
                    break;
                }
                auto arg = consumeItem();
                // log("%% arg:", arg, ":", arg.type);
                if (arg.type == ObjectType.Name && arg.toString() == "--")
                {
                    // XXX: what if the memory allocator reallocates
                    // the array? Are `bucket` and `kwargs` going
                    // to point to two different places or not?
                    readingKwArgs = true;
                    continue;
                }

                // Collect the arg/kwarg:
                if (readingKwArgs)
                {
                    kwargs ~= arg;
                }
                else
                {
                    args ~= arg;
                }
            }
            else
            {
                break;
            }
        }

        return new CommandCall(commandName.toString(), args, kwargs);
    }
    CommandCall foreachInline()
    {
        return new CommandCall("foreach.inline", [consumeSubList()], []);
    }

    Item consumeItem()
    {
        switch(currentChar)
        {
            case '{':
                return consumeSubString();
            case '[':
                return consumeExecList();
            case '(':
                return consumeList();
            case '<':
                return consumeInlineSectionDict();
            case '"':
            case '\'':
                auto opener = consumeChar();
                auto item = consumeString(opener);
                auto closer = consumeChar();
                assert(closer == opener);
                return item;
            default:
                return consumeAtom();
        }
    }

    Item consumeSubString()
    {
        /*
        set s {{
            something and something else
        }}
        // $s -> "something and something else"
        */

        auto open = consumeChar();
        assert(open == '{');

        if (currentChar == '{')
        {
            // It's a subString!

            // Consume the current (and second) '{':
            consumeChar();

            // Consume any opening newlines and spaces:
            consumeWhitespaces();

            char[] token;
            while (true)
            {
                if (currentChar == '}')
                {
                    consumeChar();
                    if (currentChar == '}')
                    {
                        consumeChar();

                        // Find all the blankspaces in the end of the string:
                        size_t end = token.length;
                        do
                        {
                            end--;
                        }
                        while (token[end].among!(SPACE, TAB, EOL));

                        return new String(token[0..end+1].to!string);
                    }
                    else
                    {
                        token ~= '}';
                    }
                }
                else if (currentChar == '\n')
                {
                    token ~= consumeChar();
                    consumeWhitespaces();
                    continue;
                }
                token ~= consumeChar();
            }
        }
        else
        {
            auto subprogram = consumeSubProgram();
            auto close = consumeChar();
            assert(close == '}');
            return subprogram;
        }
    }

    SubProgram consumeSubList()
    {
        auto open = consumeChar();
        assert(open == '{');
        auto subprogram = consumeSubProgram();
        auto close = consumeChar();
        assert(close == '}');

        return subprogram;
    }

    ExecList consumeExecList()
    {
        auto open = consumeChar();
        assert(open == '[');
        auto subprogram = consumeSubProgram();
        auto close = consumeChar();
        assert(close == ']');

        return new ExecList(subprogram);
    }

    List consumeList()
    {
        Item[] items;
        auto open = consumeChar();
        assert(open == '(');

        while (currentChar != ')')
        {
            items ~= consumeItem();
            if (isWhitespace)
            {
                consumeWhitespaces();
            }
        }

        auto close = consumeChar();
        assert(close == ')');

        log("%% List.items: ", items);
        return new List(items);
    }

    override String consumeString(char opener, bool limit_to_eol=false)
    {
        string token;
        Items parts;
        bool hasSubstitution = false;

        ulong index = 0;
        while (!eof && currentChar != opener)
        {
            if (currentChar == '$')
            {
                if (token.length)
                {
                    parts ~= new String(token);
                    token = new char[0];
                }

                // Consume the '$':
                consumeChar();

                // Current part:
                if (currentChar.among('(', '['))
                {
                    parts ~= consumeItem();
                    hasSubstitution = true;
                    continue;
                }

                bool enclosed;
                if (currentChar == '{')
                {
                    enclosed = true;
                    consumeChar();
                }

                while (!eof && ((currentChar >= 'a' && currentChar <= 'z')
                        || (currentChar >= '0' && currentChar <= '9')
                        || currentChar == '.' || currentChar == '_'))
                {
                    token ~= consumeChar();
                }

                if (token.length != 0)
                {
                    if (enclosed)
                    {
                        assert(currentChar == '}');
                        consumeChar();
                    }

                    parts ~= new Reference(token);
                    hasSubstitution = true;
                }
                else
                {
                    throw new Exception(
                        "Invalid string: "
                        ~ "parts:" ~  parts.to!string
                        ~ "; token:" ~ cast(string)token
                        ~ "; length:" ~ token.length.to!string
                    );
                }
                token = new char[0];
            }
            else if (currentChar == '\\')
            {
                // Discard the escape charater:
                consumeChar();

                // And add the next char, whatever it is:
                switch (currentChar)
                {
                    /*
                    Interesting reference:
                    http://odin-lang.org/docs/overview/#escape-characters
                    */
                    // XXX: this cases could be written at compile time.
                    case 'b':
                        token ~= '\b';
                        consumeChar();
                        break;
                    case 'n':
                        token ~= '\n';
                        consumeChar();
                        break;
                    case 'r':
                        token ~= '\r';
                        consumeChar();
                        break;
                    case 't':
                        token ~= '\t';
                        consumeChar();
                        break;
                    // TODO: \u1234
                    default:
                        token ~= consumeChar();
                }
            }
            else
            {
                token ~= consumeChar();
            }
        }

        // Adds the eventual last part (in
        // simple strings it will be
        // the first part, always:
        if (token.length)
        {
            parts ~= new String(token);
        }

        if (hasSubstitution)
        {
            return new SubstString(parts);
        }
        else if (parts.length == 1)
        {
            return cast(String)(parts[0]);
        }
        else
        {
            return new String("");
        }
    }

    Item consumeAtom()
    {
        char[] token;

        bool isNumber = true;
        bool isSubst = false;
        uint dotCounter = 0;

        // `$x`
        if (currentChar == '$')
        {
            isNumber = false;
            isSubst = true;
            // Do NOT add `$` to the Reference.
            consumeChar();
        }
        // -2
        else if (currentChar == '-')
        {
            token ~= consumeChar();
        }

        // The rest:
        while (!eof && !isWhitespace)
        {
            if (currentChar >= '0' && currentChar <= '9')
            {
            }
            else if (currentChar == '.')
            {
                dotCounter++;
            }
            else if (currentChar >= 'A' && currentChar <= 'Z')
            {
                uint* p = (currentChar in units);
                if (p is null)
                {
                    throw new Exception(
                        "Invalid character in name: "
                        ~ cast(string)token
                        ~ currentChar.to!string
                    );
                }
                else
                {
                    // Do not consume the unit.
                    break;
                }
            }
            else if (token.length && isBlockCloser)
            {
                break;
            }
            else
            {
                isNumber = false;
            }
            token ~= consumeChar();
        }

        string s = cast(string)token;

        // 123
        // .2
        if (isNumber)
        {

            // .
            // (a dot, alone)
            // -
            // (a dash, alone)
            if (s == "-" || s == ".")
            {
                return new Name(s);
            }
            else if (dotCounter == 0)
            {
                uint multiplier = 1;
                uint* p = (currentChar in units);
                if (p !is null)
                {
                    consumeChar();
                    if (currentChar == 'i')
                    {
                        consumeChar();
                        multiplier = pow(1024, *p);
                    }
                    else
                    {
                        multiplier = pow(1000, *p);
                    }
                }

                return new Integer(s.to!int * multiplier);
            }
            else if (dotCounter == 1)
            {
                return new Float(s.to!float);
            }
            else
            {
                throw new Exception(
                    "Invalid atom format: "
                    ~ s
                );
            }
        }
        else if (isSubst)
        {
            return new Reference(s);
        }

        // Handle hexadecimal format, like 0xabcdef
        if (s.length > 2 && s[0..2] == "0x")
        {
            // XXX: should we handle FormatException, here?
            auto result = toLong(s);
            return new Integer(result);
        }

        // Names that are boolean:
        switch (s)
        {
            case "true":
                return new Boolean(true);
            case "false":
                return new Boolean(false);
            default:
                return new Name(s);
        }

    }
}
