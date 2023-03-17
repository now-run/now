module now.nodes;


public import std.stdio;

public import std.algorithm.iteration : each, filter, map;
public import std.range : back, front, popBack, popFront, retro;
public import std.array : array, empty, join, split;
public import std.conv : to;

public import now.exceptions;

public import now.context;
public import now.escopo;

public import now.base_command;
public import now.procedure;
public import now.system_command;
public import now.shell_script;

// Items
public import now.nodes.item;

public import now.nodes.baselist;
public import now.nodes.list;
public import now.nodes.execlist;

public import now.nodes.dict;
public import now.nodes.vectors;

public import now.nodes.error;


public import now.nodes.program;
public import now.nodes.subprogram;
public import now.nodes.pipeline;
public import now.nodes.command_call;
public import now.nodes.strings;

public import now.nodes.atom;

alias Items = Item[];
alias Command = Context function(string, Context);
alias CommandsMap = Command[string];

enum ExitCode
{
    Undefined,
    Success,  // A command was executed with success
    Failure,  // terminated with errors
    Return,  // returned without errors
    Break,  // Break the current loop
    Continue,  // Continue to the next iteraction
    Skip,  // Skip this iteration and call `next` again
}

enum ErrorCode
{
    Unknown = 1,
    InternalError,

    Undefined,
    NotFound,
    CommandNotFound,

    Invalid,
    InvalidArgument,
    InvalidSyntax,
    InvalidInput,

    NotImplemented,

    SemanticError,

    Empty,
    Full,

    Overflow,
    Underflow,

    AssertionError,
    RuntimeError,
}

enum ObjectType
{
    Undefined,
    Other,
    None,

    List,
    ExecList,
    SubProgram,
    Error,

    Dict,
    String,
    Name,
    Atom,
    Float,
    Integer,
    Boolean,
    Numerical,
    Vector,
    Range,

    Program,
    SystemProcess,
    SystemProcessError,
}
