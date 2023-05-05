module now.commands.terminal;


import now;


extern(C) int isatty(int);

bool isTTY()
{
    return cast(bool)isatty(stdout.fileno);
}


auto reverseVideo = "\033[7m";
auto fgPrefix = "\033[38;2;";
auto bgPrefix = "\033[48;2;";
auto ansiResetCode = "\033[0m";


ExitCode printColor(int red, int green, int blue, Input input)
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
    foreach (item; input.args)
    {
        stdout.write(item.toString);
    }
    if (isTTY)
    {
        stdout.write(ansiResetCode);
    }
    stdout.writeln();
    return ExitCode.Success;
}


void loadTerminalCommands(CommandsMap commands)
{
    // print.color red "ERROR"
    commands["print.red"] = function (string path, Input input, Output output)
    {
        return printColor(255, 0, 0, input);
    };
    commands["print.green"] = function (string path, Input input, Output output)
    {
        return printColor(0, 255, 0, input);
    };

    commands["print.gray"] = function (string path, Input input, Output output)
    {
        return printColor(120, 120, 120, input);
    };
    commands["print.blue"] = function (string path, Input input, Output output)
    {
        return printColor(0, 255, 255, input);
    };
    commands["print.yellow"] = function (string path, Input input, Output output)
    {
        return printColor(255, 255, 0, input);
    };
    commands["print.emphasis"] = function (string path, Input input, Output output)
    {
        if (isTTY)
        {
            stdout.write(reverseVideo);
        }
        foreach (item; input.args)
        {
            stdout.write(item.toString);
        }
        if (isTTY)
        {
            stdout.write(ansiResetCode);
        }
        stdout.writeln();
        return ExitCode.Success;
    };
}
