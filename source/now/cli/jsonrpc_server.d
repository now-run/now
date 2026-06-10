module now.jsonrpc_server;

import now;
import now.cli;


int main(string[] args)
{
    return cliMain(args, &jsonrpcServer);
}

int jsonrpcServer(Document document, string[] documentArgs)
{
    log("+ jsonrpcServer");
    return 0;
}
