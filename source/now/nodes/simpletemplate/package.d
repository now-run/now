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
    log("parseTemplate: ", name);
    auto tpl = parseTemplate(name, info["body"].toString());
    log("parsed! ");
    info.on(
        "extends",
        delegate (item) {
            string parentName = item.toString();
            auto parent = templates[parentName];
            log(" parentName: ", parentName);
            log(" parent type: ", parent.type);
            if (parent.type == ObjectType.Dict)
            {
                auto parentBlock = parseTemplate(
                    parentName, cast(Dict)parent, templates
                );
                templates[parentName] = parentBlock;
                (cast (ExpandableBlock)tpl).extends = cast(ExpandableBlock)parentBlock;
            }
            else
            {
                (cast (ExpandableBlock)tpl).extends = cast(ExpandableBlock)parent;
            }
        }, delegate () {
            log("  this template doesn't extend any other.");
        }
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

        log("> consumeBlock: ", name);

        while (!eof)
        {
            auto blanksCount = consumeSpaces(false);
            if (eof) break;

            if (currentChar == '%')
            {
                if (text.length)
                {
                    blocks ~= new TextBlock(text.join());
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
                    log("-- block end");
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
            blocks ~= new TextBlock(text.join());
            text.length = 0;
        }
        return new ExpandableBlock(name, blocks);
    }
}

class Block : Item
{
    bool isText()
    {
        return false;
    }
    bool isExpandable()
    {
        return false;
    }
}
class TextBlock : Block
{
    String text;

    this(string text)
    {
        auto parser = new NowParser(text);
        log(" new Block, parsing: ", text);
        this.text = parser.consumeString(cast(char)null);
        log("  result: ", this.text);
    }

    override bool isText()
    {
        return true;
    }
    override bool isExpandable()
    {
        return false;
    }

    override string toString()
    {
        return text.toString();
    }
}
class ExpandableBlock : Block
{
    ExpandableBlock extends;
    string name;
    Block[] children;

    this(string name, Block[] children)
    {
        this.name = name;
        this.children = children;
        log(" new Expandable Block: ", name);
    }

    override bool isText()
    {
        return false;
    }
    override bool isExpandable()
    {
        return true;
    }

    override string toString()
    {
        return children.map!(x => x.toString()).join("\n");
    }
}



alias TemplateInstances = TemplateInstance[];
alias Template = Block;

class TemplateInstance : Item
{
    string name;
    ExpandableBlock tpl;
    bool finished = false;

    Item[string] variables;

    TemplateInstances[string] emittedBlocks;
    TemplateInstance[string] notEmittedBlocks;
    ExpandableBlock[string] expandableBlocks;

    this(ExpandableBlock tpl, bool expandParent=true)
    {
        this.type = ObjectType.Template;
        this.typeName = "template";
        this.methods = templateMethods;

        this.name = tpl.name;
        log("new TemplateInstance:", tpl.name);

        if (tpl.extends is null || !expandParent)
        {
            this.tpl = tpl;
        }
        else if (expandParent)
        {
            log(" it extends the template ", tpl.extends.name);
            this.tpl = tpl.extends;
        }

        foreach (block; this.tpl.children)
        {
            if (block.isExpandable)
            {
                auto b = cast(ExpandableBlock)block;
                log("   the block ", b.name, " is expandable");
                expandableBlocks[b.name] = b;
            }
        }
        foreach (block; this.tpl.children)
        {
            if (block.isExpandable)
            {
                auto b = cast(ExpandableBlock)block;
                log("   the block ", b.name, " is expandable");
                expandableBlocks[b.name] = b;
            }
        }
        if (this.tpl != tpl)
        {
            foreach (block; tpl.children)
            {
                if (block.isExpandable)
                {
                    auto b = cast(ExpandableBlock)block;
                    log("   > the block ", b.name, " is expandable");
                    expandableBlocks[b.name] = b;
                }
            }
        }
        log(">>> TemplateInstance created <<<");
    }
    this(ExpandableBlock tpl, Item[string] variables, bool expandParent=true)
    {
        this.variables = variables;
        this(tpl, expandParent);
        // log(" variables:", variables);
    }

    bool emit(string blockName, Item[string] variables)
    {
        log(" ", name, ".emit ", blockName);

        if (finished)
        {
            log("REFUSED. This block is finished.");
            return false;
        }

        // Were we in the middle of emitting a block?
        auto instancePtr = (blockName in notEmittedBlocks);
        if (instancePtr !is null)
        {
            auto instance = *instancePtr;
            log("   notEmitted instance: ", instance);
            instance.variables = variables;
            instance.finished = true;
            emittedBlocks[blockName] ~= instance;
            notEmittedBlocks.remove(blockName);
            return true;
        }

        // Try to emit directly:
        auto blockPtr = (blockName in expandableBlocks);
        if (blockPtr !is null)
        {
            auto expandableBlock = *blockPtr;
            log("  is expandable!");
            emittedBlocks[blockName] ~= new TemplateInstance(
                expandableBlock, variables
            );
            return true;
        }

        // Try every emitted child:
        log("  not expandable.");
        foreach (emittedBlock; emittedBlocks.byValue)
        {
            log("   emittedBlock: ", emittedBlock);
            if (emittedBlock[$-1].emit(blockName, variables))
            {
                log("emitted!");
                return true;
            }
        }

        // Try every not-emitted-yet child:
        foreach (instance; notEmittedBlocks)
        {
            log("   notEmittedBlock: ", instance);
            if (instance.emit(blockName, variables))
            {
                log("emitted!");
                return true;
            }
        }

        // Try every other possible block:
        foreach (block; expandableBlocks)
        {
            log("   expandableBlock: ", block);
            auto t = new TemplateInstance(block, false);
            notEmittedBlocks[block.name] = t;
            if (t.emit(blockName, variables))
            {
                log("emitted!");
                return true;
            }
        }

        return false;
    }

    string render(Escopo escopo)
    {
        string s;

        auto blockScope = escopo.addPathEntry(name);

        foreach (key, value; variables)
        {
            log("block:", name, ".escopo[", key, "]=", value);
            blockScope[key] = value;
        }

        foreach (block; tpl.children)
        {
            if (block.isText)
            {
                auto b = cast(TextBlock)block;
                foreach (item; b.text.evaluate(blockScope))
                {
                    s ~= item.toString();
                }
            }
            else
            {
                auto b = cast(ExpandableBlock)block;
                auto blockName = b.name;
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
