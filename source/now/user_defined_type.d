module now.user_defined_type;


import now;


Procedure[string][string] userDefinedMethods;


auto methodRunner = function (Item object, string path, Input input, Output output)
{
    log(">>> methodRunner for ", object, "/", object.type);
    auto method = userDefinedMethods[object.typeName][path];
    log(">>>> method: ", method);
    input.escopo["self"] = object;
    // XXX: should we create a new Escopo???
    return method.run(path, input, output, true);
};


class UserDefinedType : BaseCommand
{
    SubProgram constructor;
    SubProgram destructor;

    this(string name, Dict info)
    {
        super(name, info);

        auto bodyString = info["body"];
        auto parser = new NowParser(bodyString.toString());
        parser.line = bodyString.documentLineNumber;
        this.constructor = parser.consumeSubProgram();

        auto m = info.getOrCreate!Dict("methods");
        foreach (methodName, methodInfo; m.values)
        {
            Dict methodInfoDict = cast(Dict)methodInfo;
            userDefinedMethods[name][methodName] = new Procedure(methodName, methodInfoDict);
        }
    }

    override ExitCode doRun(string name, Input input, Output output)
    {
        input.escopo.rootCommand = this;
        auto exitCode = this.constructor.run(input.escopo, output);
        log(">>> constructor exitCode: ", exitCode);
        if (exitCode == ExitCode.Return)
        {
            foreach (item; output.items)
            {
                // Set the type name of each returned item as the
                // name of this type.
                item.typeName = this.name;

                // Adjust its methods:
                auto m = info.get!Dict("methods");
                foreach (methodName; m.order)
                {
                    log(">>> user defined method: ", methodName);
                    item.methods[methodName] = methodRunner;
                    // To allow for inheritance even on user-defined
                    // types, we prefix all methods with this current
                    // type name:
                    item.methods[this.name ~ "." ~ methodName] = methodRunner;
                }
            }
        }
        return exitCode;
    }
}
