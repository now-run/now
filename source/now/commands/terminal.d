module now.commands.terminal;

import now.nodes;


extern(C) int isatty(int);

bool isTTY()
{
    return cast(bool)isatty(stdout.fileno);
}


auto fgPrefix = "\033[38;2;";
auto bgPrefix = "\033[48;2;";
auto ansiResetCode = "\033[0m";


Context printColor(int red, int green, int blue, Context context)
{
    if (isTTY)
    {
        stdout.write(
            fgPrefix,
            red.to!string, ";",
            green.to!string, ";",
            blue.to!string, "m"
        );
    }
    while(context.size) stdout.write(context.pop!string());
    if (isTTY)
    {
        stdout.write(ansiResetCode);
    }
    stdout.writeln();
    return context;
}


void loadTerminalCommands(CommandsMap commands)
{
    // print.color red "ERROR"
    commands["print.red"] = function (string path, Context context)
    {
        return printColor(255, 0, 0, context);
    };
    commands["print.green"] = function (string path, Context context)
    {
        return printColor(0, 255, 0, context);
    };

    commands["print.gray"] = function (string path, Context context)
    {
        return printColor(120, 120, 120, context);
    };
    commands["print.blue"] = function (string path, Context context)
    {
        return printColor(0, 255, 255, context);
    };
    commands["print.yellow"] = function (string path, Context context)
    {
        return printColor(255, 255, 0, context);
    };
}
