module now.nodes;


import now;


public import now.common;

// Items
public import now.nodes.item;
public import now.nodes.sequence;

public import now.nodes.document;

public import now.nodes.name;
public import now.nodes.reference;
public import now.nodes.boolean;
public import now.nodes.integer;
public import now.nodes.floats;
public import now.nodes.strings;

public import now.nodes.list;
public import now.nodes.execlist;

public import now.nodes.dict;

public import now.nodes.http;

public import now.nodes.path;
public import now.nodes.simpletemplate;

public import now.nodes.tcp;
public import now.nodes.timer;

public import now.nodes.error;

// Document execution
public import now.nodes.subprogram;
public import now.pipeline;
public import now.nodes.command_call;


CommandsMap builtinCommands;


enum ObjectType
{
    Undefined,
    Other,
    None,

    Sequence,
    Pair,
    List,
    ExecList,
    SubProgram,
    Error,

    Dict,
    String,
    Name,
    Reference,
    Float,
    Integer,
    Boolean,
    Numerical,
    Vector,
    Range,

    Path,
    Template,

    TcpConnection,
    TcpServer,
    Http,
    HttpResponse,

    Document,
    SystemProcess,
    TaskRun,

    Timer,
}

alias Items = Item[];
alias Args = Items;
alias KwArgs = Item[string];

alias Command = ExitCode function(string, Input, Output);
alias CommandsMap = Command[string];

alias Method = ExitCode function(Item, string, Input, Output);
alias MethodsMap = Method[string];


enum ExitCode
{
    Success,  // A command was executed with success
    Return,  // returned without errors
    Break,  // Break the current loop
    Continue,  // Continue to the next iteraction
    Skip,  // Skip this iteration and call `next` again
}

// XXX: it probably don't belong in here:
struct Input
{
    Escopo escopo;
    Items inputs;
    Args args;
    KwArgs kwargs;
    size_t stackPointer = 0;
    Items items;

    this(Escopo escopo, Items inputs, Args args, KwArgs kwargs)
    {
        this.escopo = escopo;
        this.inputs = inputs;
        this.args = args;
        this.kwargs = kwargs;
        // XXX: we can get rid of ".array" if we can find
        // the correct type declaration for "Items items"!
        this.items = chain(args, inputs).array;
    }
    string toString()
    {
        return "Input: "
            ~ escopo.name
            ~ " in:" ~ inputs.to!string
            ~ " args:" ~ args.to!string
            ~ " kwargs:" ~ kwargs.to!string;
    }
    template pop(T)
    {
        T pop()
        {
            if (stackPointer >= items.length)
            {
                throw new EmptyException(
                    escopo,
                    "Can't pop from empty Input"
                );
            }
            else
            {
                auto item = items[stackPointer++];

                static if (__traits(hasMember, T, "typeName"))
                {
                    return cast(T)item;
                }
                else
                {
                    return __traits(getMember, item, "to" ~ capitalize(T.stringof))();
                }
            }
        }
        T pop(T defaultValue)
        {
            try
            {
                return pop!T();
            }
            catch (EmptyException)
            {
                return defaultValue;
            }
        }
    }
    Items popAll()
    {
        Items values = items[stackPointer..$];
        stackPointer = items.length;
        return values;
    }
}
/*
This does not work...
alias Output = ref Items;
*/
class Output
{
    Items items;

    this()
    {
    }

    override string toString()
    {
        return items.to!string;
    }

    Item pop()
    {
        auto item = items.front;
        items.popFront;
        return item;
    }

    void push(Item item)
    {
        items ~= item;
    }
    void push(Items items)
    {
        this.items ~= items;
    }
    void push(string thing)
    {
        items ~= new String(thing);
    }
    void push(int thing)
    {
        items ~= new Integer(thing);
    }
    void push(long thing)
    {
        items ~= new Integer(thing);
    }
    void push(float thing)
    {
        items ~= new Float(thing);
    }
    void push(bool thing)
    {
        items ~= new Boolean(thing);
    }
}
