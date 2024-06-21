module now;


extern(C) int isatty(int);

bool isTTY()
{
    return cast(bool)isatty(stdout.fileno);
}
bool isInputTTY()
{
    return cast(bool)isatty(stdin.fileno);
}


public import now.conv;
public import now.exceptions;
public import now.grammar;

public import now.nodes;

public import now.escopo;

public import now.base_command;
public import now.procedure;
public import now.system_command;
public import now.shell_script;
// public import now.commands;
