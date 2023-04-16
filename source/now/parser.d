module now.parser;

public import std.algorithm : among, canFind;
import std.math : pow;

import now.conv;
import now.nodes;


const EOL = '\n';
const SPACE = ' ';
const TAB = '\t';
const PIPE = '|';
const STOPPERS = [')', '>', ']', '}'];



class IncompleteInputException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

class Parser
{
    size_t index = 0;
    string code;
    bool eof = false;

    size_t line = 1;
    size_t col = 0;

    string[] stack;

    this(string code)
    {
        this.code = code;
    }

    // --------------------------------------------
    char currentChar()
    {
        return code[index];
    }
    char lastChar()
    {
        return code[index - 1];
    }
    char consumeChar()
    {
        if (eof)
        {
            throw new IncompleteInputException(
                "Code input already ended."
                ~ " Last char: [" ~ currentChar.to!string ~ "]"
                ~ " line=" ~ line.to!string
                ~ " char=" ~ col.to!string
                ~ " code:\n" ~ code
            );
        }
        debug {
            if (code[index] == EOL)
            {
                stderr.writeln("consumed: eol");
            }
            else
            {
                stderr.writeln("consumed: '", code[index], "'");
            }
        }
        auto result = code[index++];
        col++;

        if (result == EOL)
        {
            col = 0;
            line++;
            debug {stderr.writeln("== line ", line, " ==");}
        }

        if (index >= code.length)
        {
            debug {stderr.writeln("CODE ENDED");}
            this.eof = true;
            index--;
        }

        return result;
    }

    // --------------------------------------------
    long consumeWhitespaces(bool ignoreComments=true)
    {
        if (eof) return 0;

        long counter = 0;

        while (!eof)
        {
            // Common whitespaces:
            while (isWhitespace && !eof)
            {
                consumeChar();
                counter++;
            }
            // Comments:
            if (ignoreComments && currentChar == '#')
            {
                consumeLine();
            }
            else {
                break;
            }
        }

        debug {
            if (counter)
            {
                stderr.writeln("whitespaces (" ~ counter.to!string ~ ")");
            }
        }
        return counter;
    }
    long consumeBlankspaces(bool ignoreComments=true)
    {
        if (eof) return 0;

        long counter = 0;

        // Common whitespaces:
        while (!eof && currentChar == SPACE)
        {
            consumeChar();
            counter++;
        }
        // Comments:
        if (ignoreComments && currentChar == '#')
        {
            consumeLine();
        }

        debug {
            if (counter)
            {
                stderr.writeln("whitespaces (" ~ counter.to!string ~ ")");
            }
        }
        return counter;
    }
    string consumeLine()
    {
        string result;

        while (!eof && currentChar != EOL)
        {
            result ~= consumeChar();
        }
        if (currentChar == EOL) {
            consumeChar();
        }
        return result;
    }
    void consumeWhitespace()
    {
        if (!isWhitespace)
        {
            throw new Exception(
                "Expecting whitespace, found " ~ currentChar.to!string
            );
        }
        debug {stderr.writeln("whitespace");}
        consumeChar();
    }
    void consumeSpace()
    {
        debug {stderr.writeln("  SPACE");}
        assert(currentChar == SPACE);
        consumeChar();
    }
    bool isWhitespace()
    {
        return cast(bool)currentChar.among!(SPACE, TAB, EOL);
    }
    bool isSignificantChar()
    {
        if (this.eof) return false;
        return !isWhitespace();
    }
    bool isEndOfLine()
    {
        return eof || currentChar == EOL;
    }
    bool isStopper()
    {
        return (eof
                || currentChar == '}' || currentChar == ']'
                || currentChar == ')' || currentChar == '>');
    }

    // --------------------------------------------
    // Nodes
    string consume_string(char opener, bool limit_to_eol=false)
    {
        char[] token;

        ulong index = 0;
        while (!eof && currentChar != opener)
        {
            if (limit_to_eol && currentChar == EOL) break;

            if (currentChar == '\\')
            {
                // Discard the escape charater:
                consumeChar();

                // And add the next char, whatever it is:
                switch (currentChar)
                {
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

        return token.to!string;
    }
    String consumeString(char opener, bool limit_to_eol=false)
    {
        string s = consume_string(opener, limit_to_eol);
        return new String(s);
    }

    Item consumeNumber()
    {
        char[] token;

        uint dotCounter = 0;

        // -2
        if (currentChar == '-')
        {
            token ~= consumeChar();
        }

        // The rest:
        while (!eof && !isWhitespace)
        {
            // TODO: focus on numbers!
            if (currentChar >= '0' && currentChar <= '9')
            {
            }
            else if (currentChar == '.')
            {
                dotCounter++;
            }
            else if (token.length && STOPPERS.canFind(currentChar))
            {
                break;
            }
            else
            {
                throw new InvalidException(
                    "Invalid number format: "
                    ~ token.to!string
                    ~ " <- "
                    ~ currentChar.to!string
                );
            }
            token ~= consumeChar();
        }

        debug {stderr.writeln(" token: ", token);}

        string s = cast(string)token;
        debug {stderr.writeln(" s: ", s);}

        // .
        // (a dot, alone)
        // -
        // (a dash, alone)
        if (s == "-" || s == ".")
        {
            throw new InvalidException(
                "Invalid number format: "
                ~ s
            );
        }
        else if (dotCounter == 0)
        {
            debug {stderr.writeln("new IntegerAtom: ", s);}
            return new IntegerAtom(s.to!int);
        }
        else if (dotCounter == 1)
        {
            debug {stderr.writeln("new FloatAtom: ", s);}
            return new FloatAtom(s.to!float);
        }
        else
        {
            throw new InvalidException(
                "Invalid number format: "
                ~ s
            );
        }
    }
}
