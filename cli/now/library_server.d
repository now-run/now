module now.library_server;

import std.json;
import std.string : toLower;

import now;
import now.cli;
import now.env_vars;
import now.json;


int libraryServer(Document document, string[] documentArgs)
{
    log("+ libraryServer");

    // ------------------------------
    // Prepare the root scope:
    auto rootScope = new Escopo(document, "library_server");
    log("+ rootScope: ", rootScope);
    rootScope["env"] = envVars;

    JSONValue data;
    foreach (line; stdin.byLine)
    {
        try
        {
            data = parseJSON(line);
        }
        catch (JSONException ex)
        {
            stderr.writeln("error> ", ex.message);
            // "[\"error\",\"${procedure}\",[\"self inflicted error\"],{}]"
            auto e = JSONValue([
                JSONValue("error"),
                JSONValue(""),
                JSONValue([ex.message]),
                JSONValue(["code": JSONValue(1), "call": JSONValue(line)])
            ]);
            stdout.writeln(e);
            stdout.flush();
            continue;
        }

        string op, rpcName;
        JSONValue args, kwargs;
        try
        {
            op = data[0].str;
            rpcName = data[1].str;
            args = data[2];
            kwargs = data[3];
        }
        catch (JSONException ex)
        {
            stderr.writeln("error> ", ex.message);
            // "[\"error\",\"${procedure}\",[\"self inflicted error\"],{}]"
            auto e = JSONValue([
                JSONValue("error"),
                JSONValue(rpcName),
                JSONValue([ex.message]),
                JSONValue(["code": JSONValue(2), "call": data])
            ]);
            stdout.writeln(e);
            stdout.flush();
            continue;
        }

        switch (op)
        {
            case "call":
                call(rootScope, rpcName, args, kwargs);
                break;
            default:
                stderr.writeln("error> unknown operation: ", op);
                // "[\"error\",\"${procedure}\",[\"self inflicted error\"],{}]"
                auto e = JSONValue([
                    JSONValue("error"),
                    JSONValue(rpcName),
                    JSONValue(["Unknown operation: " ~ op]),
                    JSONValue(["code": JSONValue(3), "call": data, "op": JSONValue(op)])
                ]);
                stdout.writeln(e);
                stdout.flush();
        }
    }

    return 0;
}

void call(Escopo rootScope, string rpcName, JSONValue jArgs, JSONValue jKwargs)
{
    auto args = JsonToItem(jArgs);
    auto kwargs = JsonToItem(jKwargs);

    auto escopo = new Escopo(rootScope, rpcName);
    auto document = rootScope.document;

    auto input = Input(
        escopo,
        cast(Items)[],
        (cast(List)args).items,
        (cast(Dict)kwargs).values
    );
    log("  + input: ", input);
    ExitCode exitCode;
    auto output = new Output;

    log("+ Running ", rpcName, "...");
    try
    {
        exitCode = errorPrinter({
            return document.runProcedure(rpcName, input, output);
        });
    }
    // TODO: all this should be implemented by Document class, right?
    catch (NowException ex)
    {
        log("+++ EXCEPTION: ", ex);
        // Global error handler:
        if (document.errorHandler !is null)
        {
            auto newScope = escopo.addPathEntry("on.error");
            // TODO: do not set "error" on parent scope too.
            auto error = ex.toError();
            newScope["error"] = error;

            ExitCode errorExitCode;
            auto errorOutput = new Output;

            try
            {
                errorExitCode = document.errorHandler.run(newScope, errorOutput);
            }
            catch (NowException ex2)
            {
                stdout.writeln(JSONValue([
                    JSONValue("error"),
                    JSONValue(rpcName),
                    JSONValue([ex2.message]),
                    JSONValue.emptyObject,
                ]));
                stdout.flush();
                return;
            }

            // If the Document error handler returned successfully:
            JSONValue return_result = ItemToJson(new List(errorOutput.items));
            stdout.writeln(JSONValue([
                JSONValue("return"),
                JSONValue(rpcName),
                JSONValue(return_result),
                JSONValue.emptyObject,
            ]));
            stdout.flush();
            return;
        }
        else
        {
            stdout.writeln(JSONValue([
                JSONValue("error"),
                JSONValue(rpcName),
                JSONValue([ex.message]),
                JSONValue.emptyObject,
            ]));
            stdout.flush();
            return;
        }
    }

    string exitCodeString = (exitCode.to!string).toLower;
    if (exitCodeString == "success")
    {
        exitCodeString = "return";
    }

    // In case the call was successful:
    JSONValue return_result = ItemToJson(new List(output.items));
    auto response = JSONValue([
        JSONValue(exitCodeString),
        JSONValue(rpcName),
        JSONValue(return_result),
        JSONValue(JSONValue.emptyObject),
    ]);
    stdout.writeln(response);
    stdout.flush();
}
