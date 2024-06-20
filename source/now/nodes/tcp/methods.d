module now.nodes.tcp.methods;


import std.socket;

import now;


static this()
{
    tcpConnectionMethods["next"] = function (Item object, string name, Input input, Output output)
    {
        TcpConnection c = cast(TcpConnection)object;
        return c.next(input.escopo, output);
    };

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
        foreach (item; input.popAll)
        {
            size_t sent;
            size_t length;
            if (item.type == ObjectType.String)
            {
                string msg = item.toString;
                length = msg.length;
                log("socket send msg=", msg);
                sent = c.socket.send(msg);
            }
            else
            {
                throw new InvalidArgumentsException(
                    input.escopo,
                    "Invalid argument type for send: " ~ item.type.to!string,
                    -1,
                    item
                );
            }
            if (sent == Socket.ERROR || sent < length)
            {
                throw new TcpSocketException(
                    input.escopo,
                    "Error while sending data to TCP socket.",
                    -1,
                    item
                );
            }
        }
        return ExitCode.Success;
    };
}
