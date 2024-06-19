module now.nodes.tcp.methods;


import std.socket;

import now;


static this()
{
    // About whatever the path points to:
    tcpConnectionMethods["close"] = function (Item object, string name, Input input, Output output)
    {
        TcpConnection c = cast(TcpConnection)object;
        c.socket.close();
        return ExitCode.Success;
    };
    tcpConnectionMethods["send"] = function (Item object, string name, Input input, Output output)
    {
        TcpConnection c = cast(TcpConnection)object;
        log("socket send input.items=", input.items);
        string msg = input.pop!string;
        log("socket send msg=", msg);

        auto sent = c.socket.send(msg);
        if (sent == Socket.ERROR || sent < msg.length)
        {
            throw new TcpSocketException(
                input.escopo,
                "Error while sending data to TCP socket.",
                -1,
                c
            );
        }
        return ExitCode.Success;
    };
}
