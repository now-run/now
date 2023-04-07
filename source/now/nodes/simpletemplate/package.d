module now.nodes.simpletemplate;

import std.string : rightJustify;

import now.grammar;
import now.nodes;
import now.parser;


CommandsMap templateCommands;


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

Block parseTemplate(string name, Dict info)
{
    auto tpl = parseTemplate(name, info["body"].toString());
    info.on(
        "extends",
        delegate (item) {
            tpl.extends = item.toString();
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

        while (!eof)
        {
            auto blanksCount = consumeBlankspaces();
            if (currentChar == '%')
            {
                if (text.length)
                {
                    blocks ~= new Block(text.join(EOL));
                    text.length = 0;
                }

                // "   % block_name % and the rest is ignored"
                assert(consumeChar() == '%', currentChar.to!string);
                assert(consumeChar() == SPACE, currentChar.to!string);
                string blockName = consume_string(SPACE);
                assert(consumeChar() == SPACE, currentChar.to!string);
                assert(consumeChar() == '%', currentChar.to!string);

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
                text ~= spacer ~ consumeLine();
            }
        }
        if (text.length)
        {
            blocks ~= new Block(text.join(EOL));
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

    string extends;

    this(string text)
    {
        auto parser = new NowParser(text);
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


class TemplateInstance : Item
{
    string name;
    Block tpl;

    Item[string] variables;

    TemplateInstances[string] emittedBlocks;
    Block[string] expandableBlocks;

    this(Block tpl)
    {
        this.type = ObjectType.Template;
        this.typeName = "template";
        this.commands = templateCommands;

        this.tpl = tpl;
        this.name = tpl.name;

        foreach (block; tpl.children)
        {
            if (block.isExpandable)
            {
                expandableBlocks[block.name] = block;
            }
        }
    }
    this(Block tpl, Item[string] variables)
    {
        this(tpl);
        this.variables = variables;
    }

    void emit(string blockName, Item[string] variables)
    {
        auto blockPtr = (blockName in expandableBlocks);
        if (blockPtr !is null)
        {
            auto expandableBlock = *blockPtr;
            emittedBlocks[blockName] ~= new TemplateInstance(
                expandableBlock, variables
            );
        }
        else
        {
            foreach (emittedBlock; emittedBlocks.byValue)
            {
                emittedBlock[$-1].emit(blockName, variables);
            }
        }
    }

    string render(Context context)
    {
        string s;

        auto newScope = new Escopo(context.escopo);
        foreach (key, value; variables)
        {
            newScope[key] = [value];
        }

        auto newContext = context.next(newScope);
        foreach (block; tpl.children)
        {
            if (block.isText)
            {
                newContext = block.text.evaluate(newContext);
                s ~= newContext.pop!string();
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
                        s ~= emittedBlock.render(newContext);
                    }
                }
            }
        }

        if (tpl.extends !is null)
        {
            auto templates = context.program.getOrCreate!Dict("templates");
            auto parent = cast(Block)(templates[tpl.extends]);

            variables["body"] = new String(s);
            auto parentInstance = new TemplateInstance(parent, variables);
            return parentInstance.render(context);
        }

        return s;
    }

    override string toString()
    {
        return tpl.toString();
    }
}
