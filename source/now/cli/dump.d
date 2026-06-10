module now.cli.dump;

import now.cli;

import now;
import now.env_vars;


int main(string[] args)
{
    return cliMain(args, &dump);
}

int dump(Document document, string[] documentArgs)
{
    if (document is null)
    {
        return 1;
    }

    stdout.writeln("# Variables");
    foreach (key, value; document)
    {
        stdout.writeln(key, ": ", value);
    }

    stdout.writeln("# Procedures");
    foreach (name; document.procedures)
    {
        stdout.writeln(name);
    }
    stdout.writeln("# Commands");
    foreach (name; document.commands)
    {
        stdout.writeln(name);
    }
    return 0;
}
