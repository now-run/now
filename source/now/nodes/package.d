debug
{
    public import std.stdio;
}

public import std.algorithm.iteration : map;
public import std.range : back, popBack, retro;
public import std.array : join, split;
public import std.conv : to;

public import now.exceptions;

public import now.context;

public import now.procedures;
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
alias Command = void function(string, Context);
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
}
