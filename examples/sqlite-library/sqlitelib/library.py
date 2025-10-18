import json
from sys import stderr, stdin, stdout


procedures = {}


def log(*args, **kwargs):
    if kwargs:
        print(*args, kwargs, file=stderr)
    else:
        print(*args, file=stderr)


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


def run_procedure(name, args, kwargs):
    try:
        procedure = procedures[name]
    except KeyError:
        return eval(f"{name}(*args, **kwargs)")
    else:
        return procedure(*args, **kwargs)


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
                response(
                    rpc={"op": "return"},
                    result=run_procedure(name, args, kwargs)
                )
            except Exception as ex:
                cls = ex.__class__.__name__
                response(
                    rpc={"op": "error"},
                    classe=cls,
                    message=str(ex)
                )
            continue
        else:
            response(
                rpc={"op": "error"},
                classe="InvalidOperation",
                message=f"Can't handle the RPC operation: {operation}"
            )
