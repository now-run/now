module now.common;


public import std.stdio;

public import std.algorithm.iteration : each, filter, map;
public import std.array : array, empty, join, split;
public import std.conv : to;
public import std.range : back, chain, front, popBack, popFront, retro;
public import std.string : capitalize;

public import now.conv;
public import now.exceptions;


void log(Args...)(Args args)
{
    debug {
        stderr.writeln(args);
    }
}
