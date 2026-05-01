from jsonrpclib.SimpleJSONRPCServer import SimpleJSONRPCServer

server = SimpleJSONRPCServer(('localhost', 9090))
server.register_function(pow)
server.register_function(lambda x,y: x+y, 'add')
server.register_function(lambda x: x, 'ping')
server.serve_forever()
