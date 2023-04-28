module now.context;


import std.array;

import now.process;
import now.nodes;


struct Context
{
    Program program;
    Escopo escopo;
    Process process;
    ExitCode exitCode = ExitCode.Success;
    uint inputSize = 0;

    /*
    Commands CAN pop beyond local zero, so
    resist the temptation to make it an uint:
    */
    int size = 0;

    @disable this();
    this(Process process, Escopo escopo, int size=0)
    {
        this.process = process;
        this.escopo = escopo;
        this.program = escopo.program;
        this.size = size;
    }

    Context next(int argumentCount=0)
    {
        return this.next(escopo, argumentCount);
    }
    Context next(Escopo escopo, int size=0)
    {
        this.size -= size;
        auto newContext = Context(process, escopo, size);
        newContext.inputSize = this.inputSize;
        return newContext;
    }

    string toString()
    {
        string s = " process " ~ to!string(process.index);
        s ~= " (" ~ to!string(size) ~ ")";
        return s;
    }
    string description()
    {
        string[] path;

        auto pivot = escopo;
        while (pivot !is null)
        {
            if (pivot.description)
            {
                path ~= pivot.description;
            }
            else
            {
                path ~= "?";
            }
            pivot = pivot.parent;
        }

        if (process.description)
        {
            path ~= process.description;
        }
        else
        {
            path ~= "?";
        }

        return path.retro.join("/");
    }

    // Stack-related things:
    Item peek(string semantics)
    {
        return this.peek(1, semantics);
    }
    Item peek(uint index=1, string semantics=null)
    {
        return process.stack.peek(index, semantics);
    }
    template pop(T : Item)
    {
        T pop(string semantics=null)
        {
            auto info = typeid(T);
            auto value = this.pop(semantics);
            return cast(T)value;
        }
    }
    template pop(T : long)
    {
        T pop(string semantics=null)
        {
            auto value = this.pop(semantics);
            return value.toInt;
        }
    }
    template pop(T : float)
    {
        T pop(string semantics=null)
        {
            auto value = this.pop(semantics);
            return value.toFloat;
        }
    }
    template pop(T : bool)
    {
        T pop(string semantics=null)
        {
            auto value = this.pop(semantics);
            return value.toBool;
        }
    }
    template pop(T : string)
    {
        T pop(string semantics=null)
        {
            auto value = this.pop(semantics);
            return value.toString;
        }
    }
    Item pop(string semantics=null)
    {
        size--;
        return process.stack.pop(semantics);
    }
    Item popOrNull()
    {
        if (process.stack.isEmpty)
        {
            return null;
        }
        else
        {
            return this.pop();
        }
    }

    Items pop(uint count, string semantics=null)
    {
        return this.pop(cast(ulong)count, semantics);
    }
    Items pop(ulong count, string semantics=null)
    {
        size -= count;
        if (inputSize > size)
        {
            inputSize = size;
        }
        return process.stack.pop(count, semantics);
    }
    template pop(T)
    {
        T[] pop(ulong count, string semantics=null)
        {
            T[] items;
            foreach(i; 0..count)
            {
                items ~= pop!T(semantics);
            }
            return items;
        }
    }

    Context push(Item item)
    {
        process.stack.push(item);
        size++;
        return this;
    }
    Context push(Items items)
    {
        foreach(item; items)
        {
            push(item);
        }
        return this;
    }
    template push(T)
    {
        Context push(T x)
        {
            process.stack.push(x);
            size++;
            return this;
        }
    }
    Context ret(Item item)
    {
        push(item);
        exitCode = ExitCode.Success;
        return this;
    }
    Context ret(Items items)
    {
        this.push(items);
        exitCode = ExitCode.Success;
        return this;
    }

    template items(T)
    {
        T[] items(string semantics=null)
        {
            if (size > 0)
            {
                return pop!T(size, semantics);
            }
            else
            {
                return [];
            }
        }
    }
    Items items(string semantics=null)
    {
        if (size > 0)
        {
            auto x = size;
            size = 0;
            inputSize = 0;
            return process.stack.pop(x, semantics);
        }
        else
        {
            return [];
        }
    }

    // Errors
    Context error(string message, int code, string classe, Item object=null)
    {
        auto e = new Erro(message, code, classe, this, object);
        push(e);
        this.exitCode = ExitCode.Failure;
        return this;
    }
}
