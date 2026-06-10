module now.cli.stdin;

import now.cli;
import now;
import now.env_vars;


int main(string[] args)
{
    return cliMain(args, &processStdin);
}


int processStdin(Document documentPath, string[] args)
{
    documentPath = stdin.name;
    // TODO
}
