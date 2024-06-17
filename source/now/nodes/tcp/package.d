module now.nodes.tcp;


import std.socket;
import now;


MethodsMap tcpConnectionMethods;
MethodsMap tcpServerMethods;


const BUFFER_SIZE = 128;
const BUFFER_INCREMENT = 1024;


class TcpConnection : Item
{
    TcpServer server;
    Socket socket;

    this(TcpServer server, Socket socket)
    {
        this.server = server;
        this.socket = socket;

        this.type = ObjectType.TcpConnection;
        this.typeName = "tcp_connection";
        this.methods = tcpConnectionMethods;
    }
    override string toString()
    {
        return "tcp_connection";
    }
    override Item range()
    {
        return this;
    }
    override ExitCode next(Escopo escopo, Output output)
    {
        auto buffer = new ubyte[BUFFER_SIZE];
        auto slice = buffer[0..$];
        size_t bytesCounter = 0;

        while (true)
        {
            auto received = socket.receive(slice);
            log(">>> slice:", cast(string)slice);
            bytesCounter += received;

            if (received == Socket.ERROR)
            {
                throw new TcpSocketException(
                    escopo,
                    "Error while receiving from socket.",
                    -1,
                    this
                );
            }
            else if (received == 0)
            {
                // socket was closed
                return ExitCode.Break;
            }
            else if (received == BUFFER_SIZE)
            {
                buffer.length += BUFFER_INCREMENT;
                slice = buffer[$-BUFFER_INCREMENT..$];
            }
            else
            {
                output.push(cast(string)(buffer[0..bytesCounter]));
                return ExitCode.Continue;
            }
        }
    }
}


class TcpServer : Item
{
    Socket socket;
    this(Socket socket)
    {
        this.socket = socket;
        this.type = ObjectType.TcpServer;
        this.typeName = "tcp_server";
        this.methods = tcpServerMethods;
    }
    override string toString()
    {
        return "tcp_server";
    }
    override Item range()
    {
        return this;
    }
    override ExitCode next(Escopo escopo, Output output)
    {
        log("tcp_server next");
        auto connection = socket.accept();
        log("- connection: ", connection);
        auto server = new TcpConnection(this, connection);

        output.push(server);
        return ExitCode.Continue;
    }
}
