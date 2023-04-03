module now.commands.yaml;


import now.nodes;
import now.parser;


/*
YAML can be read node-by-node, as long as you keep
control of indentation! Each node can be:
- key
- string / number
- bullet (for list)
- inline list - [a, b, c]
- inline map - {a: b, c: d}

Parsing numbers seems like a footgun, here. We consider every value a string.

There's no "document". The document is a block.
- If the block represents a dict, then it is
  composed of keys and values, being the
  keys strings and the values other
  blocks;
- If the block represents a list, then it is
  composed of a set of pairs, being each
  one of them a bullet followed by a
  block;
- If the block represents a value, then it is
  composed of a string.
*/


enum YamlNodeType
{
    String,
    Key,
    Bullet,
    // InlineList,
    // InlineMap,
    OpenBlock, CloseBlock,
}

class YamlNode
{
    YamlNodeType type;
    long indentation;
    string value;

    this(YamlNodeType type, long indentation, string value=null)
    {
        this.type = type;
        this.indentation = indentation;
        this.value = value;
    }

    override string toString()
    {
        string s = indentation.to!string
            ~ "-"
            ~ this.type.to!string;
        if (value)
        {
            s ~= "> " ~ this.value;
        }
        return s;
    }
}


class YamlParser : Parser
{
    long currentIndentation = 0;

    YamlNode[] nodes;
    long currentNodeIndex = 0;

    this(string source)
    {
        super(source);
    }

    // -------------------------------
    YamlNode currentNode()
    {
        if (currentNodeIndex >= nodes.length)
        {
            this.eof = true;
            return null;
        }
        return nodes[currentNodeIndex];
    }
    YamlNode consumeCurrentNode()
    {
        auto result = nodes[currentNodeIndex++];
        if (currentNodeIndex >= nodes.length)
        {
            this.eof = true;
        }
        return result;
    }

    // -------------------------------
    Item run()
    {
        long[256] blocks;
        long currentBlock = 0;

        nodes ~= new YamlNode(
            YamlNodeType.OpenBlock,
            0
        );
        while (!eof)
        {
            auto node = consumeNode();
            // XXX: not sure why this "ghost string"
            // appears at the end of the test file:
            if (node.type == YamlNodeType.String && node.value.length == 0)
            {
                continue;
            }

            auto lastIndentation = blocks[currentBlock];
            if (node.indentation > lastIndentation)
            {
                blocks[++currentBlock] = node.indentation;
                nodes ~= new YamlNode(
                    YamlNodeType.OpenBlock,
                    lastIndentation
                );
            }
            else if (node.indentation < lastIndentation)
            {
                long count = 0;
                for (long i = currentBlock; i >= 0; i--)
                {
                    if (node.indentation == blocks[i])
                    {
                        break;
                    }
                    else
                    {
                        count++;
                        currentBlock--;
                        nodes ~= new YamlNode(
                            YamlNodeType.CloseBlock,
                            blocks[i],  // XXX: does it make sense?
                        );
                    }
                }
                if (count == 0)
                {
                    throw new Exception("Invalid indentation");
                }
            }
            this.nodes ~= node;
        }
        for (long i = currentBlock; i >= 0; i--)
        {
            nodes ~= new YamlNode(
                YamlNodeType.CloseBlock,
                blocks[i]
            );
        }

        // Reset the "eof" flag, we are
        // now going one level up:
        this.eof = false;

        return consumeBlock();
    }

    Item consumeBlock()
    {
        // Consume the block opener:
        debug{stderr.writeln("consumeBlock:", currentNode);}
        assert (consumeCurrentNode.type == YamlNodeType.OpenBlock);

        auto result = consumeBlockContent();

        // Consume the block closer:
        assert (consumeCurrentNode.type == YamlNodeType.CloseBlock);

        return result;
    }
    Item consumeBlockContent()
    {
        debug{stderr.writeln("consumeBlockContent:", currentNode);}
        switch (currentNode.type)
        {
            case YamlNodeType.Bullet:
                return consumeList();
            case YamlNodeType.Key:
                return consumeDict();
            case YamlNodeType.String:
                return consumeString();
            default:
                throw new Exception(
                    "Do not know how to handle this type: "
                    ~ currentNode.type.to!string()
                );
        }
    }
    Dict consumeDict()
    {
        auto dict = new Dict();
        while (!eof && currentNode.type != YamlNodeType.CloseBlock)
        {
            auto key = consumeCurrentNode;
            debug{stderr.writeln("  consumeDict.key:", key);}
            assert (key.type == YamlNodeType.Key);
            dict[key.value] = consumeBlock();
        }
        return dict;
    }
    List consumeList()
    {
        debug{stderr.writeln("  consumeList");}
        Items items;
        while (!eof && currentNode.type != YamlNodeType.CloseBlock)
        {
            auto bullet = consumeCurrentNode;
            assert (bullet.type == YamlNodeType.Bullet);
            items ~= consumeBlockContent();
        }
        return new List(items);
    }
    String consumeString()
    {
        auto s = new String(consumeCurrentNode().value);
        return s;
    }

    // -----------------------------------
    YamlNode consumeNode()
    {
        long indentation;
        while (!eof)
        {
            indentation = consumeBlankspaces();
            if (currentChar == '\n')
            {
                consumeChar();
                currentIndentation = 0;
                continue;
            }
            else
            {
                break;
            }
        }

        currentIndentation += indentation;

        switch (currentChar)
        {
            case '-':
                return consumePotentialBullet();
            default:
                return consumePotentialKey();
        }
    }

    YamlNode consumePotentialBullet()
    {
        // The bullet ('-'):
        consumeChar();
        if (currentChar == SPACE)
        {
            /*
            key:
              - a: 1
                b: 2
            01234    - indentation index:
            key = 0
              Bullet = 2 - but it doesn't count!
                a = 4
                b = 4
            -----
            key:
            - a: 1
            - b: 2
            012345    - indentation index:
            key = 0
            bullet = 0
              a = 2
              b = 2
            -----
            The bullet is the equivalent of a blankspace
            for indentation purposes.
            */
            consumeWhitespace();
            currentIndentation += 2;
            return new YamlNode(YamlNodeType.Bullet, currentIndentation);
        }
        else
        {
            return consumePotentialKey();
        }
    }
    YamlNode consumePotentialKey()
    {
        /*
        At this point, we ruled out any `- ` (Bullet) lines.
        */

        bool isKey = false;
        currentIndentation += consumeBlankspaces();

        string s;
        if (currentChar.among('"', '\''))
        {
            auto opener = consumeChar();
            s = consume_string(opener);
            auto closer = consumeChar();
            assert (opener == closer);
            if (currentChar == ':')
            {
                consumeChar();
                isKey = true;
            }
        }
        else
        {
            while (!eof && currentChar != EOL)
            {
                // TODO: handle comments!
                if (currentChar == ':')
                {
                    /*
                    1) key:
                    2) key: value
                    3) http://example.org
                    */
                    auto colon = consumeChar();
                    if (currentChar.among(SPACE, EOL))
                    {
                        /*
                        key: value
                        012345
                        key:0
                        value:5
                        */
                        isKey = true;
                        break;
                    }
                    else
                    {
                        s ~= colon;
                    }
                }
                s ~= consumeChar();
            }
        }

        if (isKey)
        {
            auto keyIndentation = currentIndentation;
            // We didn't consume the SPACE yet, so it's only +1 (the colon):
            currentIndentation += s.length + 1;
            return new YamlNode(YamlNodeType.Key, keyIndentation, s);
        }
        else
        {
            return new YamlNode(
                YamlNodeType.String, currentIndentation, s
            );
        }
    }
}

void loadYamlCommands(CommandsMap commands)
{
    commands["yaml.decode"] = function (string path, Context context)
    {
        auto s = context.pop!string();
        auto parser = new YamlParser(s);
        return context.push(parser.run());
    };
}
