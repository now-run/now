module now.cli.bash_complete;


int bashAutoComplete()
{
    Document document;

    if (!defaultFilepath.exists)
    {
        return 0;
    }

    auto parser = new NowParser(defaultFilepath.read.to!string);
    document = parser.run();
    document.initialize(envVars);

    auto words = envVars["COMP_LINE"].toString().split(" ");
    string lastWord = null;
    auto ignore = 0;
    foreach (word; words.retro)
    {
        if (word.length)
        {
            lastWord = word;
            break;
        }
        ignore++;
    }
    auto n = words.length - ignore;

    if (n == 1)
    {
        stdout.writeln(document.commands.keys.join(" "));
    }
    else {
        string[] commands;
        foreach (name; document.commands.keys)
        {
            if (name.startsWith(lastWord))
            {
                commands ~= name;
            }
        }
        stdout.writeln(commands.join(" "));
    }
    return 0;
}
