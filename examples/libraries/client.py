import jsonrpclib

server = jsonrpclib.Server('http://localhost:9090')
server.add(5,6)
# 11

print("request:", jsonrpclib.history.request)
# {"jsonrpc": "2.0", "params": [5, 6], "id": "gb3c9g37", "method": "add"}
print("response:", jsonrpclib.history.response)
# {'jsonrpc': '2.0', 'result': 11, 'id': 'gb3c9g37'}
server.add(x=5, y=10)
# 15
server._notify.add(5,6)
# No result returned...

""" 
batch = jsonrpclib.MultiCall(server)
batch.add(5, 6)
batch.ping({'key':'value'})
batch._notify.add(4, 30)
results = batch()
for result in results:
... print(result)
# 11
# {'key': 'value'}
# Note that there are only two responses -- this is according to spec.
""" 
