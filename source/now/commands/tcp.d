module now.commands.tcp;


import std.socket;

import now;


void loadTCPCommands(CommandsMap commands)
{
    commands["tcp.connect"] = function (string path, Input input, Output output)
    {
        /*
        > tcp.connect localhost 8080 | as socket
        > o $socket : send "something"
        > o $socket : receive | print
        something else
        */
        string host = input.pop!string;
        auto port = input.pop!long;

        log("tcp.connect");
        auto socket = new TcpSocket(AddressFamily.INET);
        log("- connecting...");
        try
        {
            socket.connect(new InternetAddress(host, cast(ushort)port));
        }
        catch (SocketOSException ex)
        {
            throw new TcpSocketException(
                input.escopo,
                ex.msg,
                -1,
                null
            );
        }
        log("- returning connected socket");
        output.push(new TcpConnection(socket));

        return ExitCode.Success;
    };
    commands["tcp.serve"] = function (string path, Input input, Output output)
    {
        /*
        > tcp.serve $host $port | {connection_handler}
        # Run until a Break is received.
        */

        string host = input.pop!string;
        auto port = input.pop!long;

        int backlog = 128;
        Item* user_backlog_ref = ("backlog" in input.kwargs);
        if (user_backlog_ref !is null)
        {
            auto user_backlog = cast(Integer)(*user_backlog_ref);
            backlog = cast(int)user_backlog_ref.toLong;
        }

        auto socket = new TcpSocket(AddressFamily.INET);

        socket.bind(new InternetAddress(host, cast(ushort)port));
        socket.listen(backlog);
        output.push(new TcpServer(socket));

        return ExitCode.Success;
    };
}
