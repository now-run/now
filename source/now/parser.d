module now.parser;

public import std.algorithm : among, canFind;
import std.math : pow;

import now;
import now.conv;


const EOL = '\n';
const SPACE = ' ';
const TAB = '\t';
const STOPPERS = [')', ']', '}'];


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
                null,
                "Code input already ended."
                ~ " Last char: [" ~ currentChar.to!string ~ "]"
                ~ " line=" ~ line.to!string
                ~ " char=" ~ col.to!string
                ~ " code:\n" ~ code
            );
        }
        auto result = code[index++];
        col++;

        if (result == EOL)
        {
            col = 0;
            line++;
        }

        if (index >= code.length)
        {
            this.eof = true;
            index--;
        }

        return result;
    }

    // --------------------------------------------
    // Checks on currentChar:
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
    bool isBlockCloser()
    {
        return (eof || STOPPERS.canFind(currentChar));
    }

    // --------------------------------------------
    void consumeWhitespace()
    {
        if (!isWhitespace)
        {
            throw new Exception(
                "Expecting whitespace, found " ~ currentChar.to!string
            );
        }
        consumeChar();
    }
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

        return counter;
    }

    void consumeSpace()
    {
        assert(currentChar == SPACE);
        consumeChar();
    }
    long consumeSpaces(bool ignoreComments=true)
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

        return counter;
    }

    string consumeLine(bool eliminateEol=true)
    {
        string result;

        while (!eof && currentChar != EOL)
        {
            result ~= consumeChar();
        }
        if (currentChar == EOL) {
            auto eol = consumeChar();
            if (!eliminateEol)
            {
                result ~= eol;
            }
        }
        return result;
    }

    // --------------------------------------------
    string consume_string(char opener, bool limit_to_eol=false)
    {
        string token;

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

        return token;
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
                    null,
                    "Invalid number format: "
                    ~ token.to!string
                    ~ " <- "
                    ~ currentChar.to!string
                );
            }
            token ~= consumeChar();
        }

        string s = cast(string)token;

        // .
        // (a dot, alone)
        // -
        // (a dash, alone)
        if (s == "-" || s == ".")
        {
            throw new InvalidException(
                null,
                "Invalid number format: "
                ~ s
            );
        }
        else if (dotCounter == 0)
        {
            return new Integer(s.to!int);
        }
        else if (dotCounter == 1)
        {
            return new Float(s.to!float);
        }
        else
        {
            throw new InvalidException(
                null,
                "Invalid number format: "
                ~ s
            );
        }
    }
}
