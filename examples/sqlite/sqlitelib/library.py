import json
from sys import stderr, stdin, stdout


procedures = {}

def rpc(name):
    """Use this as a decorator for your functions."""

    global procedures

    def wrapper(function):
        procedures[name] = function
        return function

    return wrapper


def response(**data):
    # Yeah, don't worry, the response
    # really goes through stdout.
    print(json.dumps(data))
    stdout.flush()


def run():
    for line in stdin:
        data = json.loads(line)

        metadata = data["rpc"]
        operation = metadata["op"]

        if operation == "call":
            name = data["procedure"]
            args = data["args"]
            kwargs = data["kwargs"]

            try:
                procedure = procedures[name]
            except KeyError:
                cmd = f"{name}(*args, **kwargs)"
                print(cmd, file=stderr)
                result = eval(cmd)
                """
                response(
                    rpc={"op": "error"},
                    classe="invalid_procedure",
                    message=name
                )
                continue
                """
            else:
                result=procedure(*args, **kwargs)

            try:
                response(
                    rpc={"op": "return"},
                    result=result
                )
            except Exception as ex:
                cls = ex.__class__.__name__
                response(
                    rpc={"op": "error"},
                    classe=cls,
                    message=str(ex)
                )
            continue
