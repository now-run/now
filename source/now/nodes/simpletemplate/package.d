module now.nodes.simpletemplate;

import std.string : rightJustify;

import now;
import now.parser;


MethodsMap templateMethods;


/*
[templates/html]
<html>
    <head>$page_title</head>
    <body>
        <h1>Templates Test</h1>
        % files_list %
            <h2>Files in $directory</h2>
            <ul>
            % file %
                <li>$file</li>
            % ----- %
            </ul>
        % ----- %
    </body>
</html>
*/

Block parseTemplate(string name, Dict info, Dict templates)
{
    auto tpl = parseTemplate(name, info["body"].toString());
    info.on(
        "extends",
        delegate (item) {
            string parentName = item.toString();
            auto parentBlock = cast(Block)(templates[parentName]);
            tpl.extends = parentBlock;
        }, delegate () { }
    );
    return tpl;
}

Block parseTemplate(string name, string text)
{
    auto parser = new TemplateParser(text);
    return parser.run(name);
}


class TemplateParser : Parser
{
    this(string code)
    {
        super(code);
    }
    Block run (string name)
    {
        return consumeBlock(name);
    }
    Block consumeBlock(string name)
    {
        string[] text;
        Block[] blocks;

        debug{stderr.writeln("> consumeBlock ", name);}

        while (!eof)
        {
            auto blanksCount = consumeWhitespaces(false);
            if (eof) break;

            if (currentChar == '%')
            {
                if (text.length)
                {
                    blocks ~= new Block(text.join());
                    text.length = 0;
                }

                // "   % block_name % and the rest is ignored"
                assert(consumeChar() == '%', currentChar.to!string);
                assert(consumeChar() == SPACE, currentChar.to!string);
                string blockName = consume_string(SPACE);
                assert(consumeChar() == SPACE, currentChar.to!string);
                assert(consumeChar() == '%', currentChar.to!string);
                consumeLine();

                bool isEnd = true;
                foreach (c; blockName)
                {
                    if (c != '-')
                    {
                        isEnd = false;
                        break;
                    }
                }
                if (isEnd)
                {
                    debug{stderr.writeln("BLOCK END");}
                    break;
                }
                else
                {
                    blocks ~= consumeBlock(blockName);
                }
            }
            else
            {
                string spacer = rightJustify("", blanksCount);
                text ~= spacer ~ consumeLine(false);
            }
        }
        if (text.length)
        {
            blocks ~= new Block(text.join());
            text.length = 0;
        }
        return new Block(name, blocks);
    }
}

class Block : Item
{
    // For expandable blocks:
    string name;
    Block[] children;
    // For text blocks:
    String text;

    Block extends;

    this(string text)
    {
        auto parser = new NowParser(text);
        debug{stderr.writeln(" new Block, parsing: ", text);}
        this.text = parser.consumeString(cast(char)null);
    }
    this(string name, Block[] children)
    {
        this.name = name;
        this.children = children;
        this.text = null;
    }

    bool isText()
    {
        return (text !is null);
    }
    bool isExpandable()
    {
        return (text is null);
    }

    override string toString()
    {
        if (isText)
        {
            return text.toString();
        }
        else
        {
            return children.map!(x => x.toString()).join("\n");
        }
    }
}


alias TemplateInstances = TemplateInstance[];
alias Template = Block;

class TemplateInstance : Item
{
    string name;
    Block tpl;

    Item[string] variables;

    TemplateInstances[string] emittedBlocks;
    Block[string] expandableBlocks;

    this(Block tpl, bool expandParent=true)
    {
        this.type = ObjectType.Template;
        this.typeName = "template";
        this.methods = templateMethods;

        this.name = tpl.name;

        if (tpl.extends is null || !expandParent)
        {
            this.tpl = tpl;
        }
        else if (expandParent)
        {
            this.tpl = tpl.extends;
        }

        foreach (block; this.tpl.children)
        {
            if (block.isExpandable)
            {
                expandableBlocks[block.name] = block;
            }
        }

        if (tpl.extends !is null && expandParent)
        {
            foreach (block; tpl.children)
            {
                expandableBlocks[block.name] = block;
            }
        }
    }
    this(Block tpl, Item[string] variables, bool expandParent=true)
    {
        this.variables = variables;
        this(tpl, expandParent);
    }

    bool emit(string blockName, Item[string] variables)
    {
        // Try to emit directly:
        auto blockPtr = (blockName in expandableBlocks);
        if (blockPtr !is null)
        {
            auto expandableBlock = *blockPtr;
            emittedBlocks[blockName] ~= new TemplateInstance(
                expandableBlock, variables
            );
            return true;
        }

        // Try every child:
        foreach (emittedBlock; emittedBlocks.byValue)
        {
            if (emittedBlock[$-1].emit(blockName, variables))
            {
                return true;
            }
        }

        return false;
    }

    string render(Escopo escopo)
    {
        string s;

        foreach (block; tpl.children)
        {
            if (block.isText)
            {
                foreach (item; block.text.evaluate(escopo))
                {
                    s ~= item.toString();
                }
            }
            else
            {
                auto blockName = block.name;
                auto blockPtr = (blockName in emittedBlocks);
                if (blockPtr !is null)
                {
                    auto blocks = *blockPtr;
                    foreach (emittedBlock; blocks)
                    {
                        s ~= emittedBlock.render(escopo);
                    }
                }
            }
        }

        return s;
    }

    override string toString()
    {
        return tpl.toString();
    }
}
