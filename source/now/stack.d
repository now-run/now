module now.stack;


import now.nodes;


class Stack
{
    Item[64] stack;
    uint stackPointer = 0;

    // Stack manipulation:
    Item peek(uint index=1, string semantics=null)
    {
        uint pointer = stackPointer - index;
        debug{
            if (semantics is null)
            {
                stderr.writeln("? [", pointer, "]");
            }
            else
            {
                stderr.writeln(semantics, " ? [", pointer, "]");
            }
        }
        if (pointer < 0)
        {
            return null;
        }
        return stack[pointer];
    }
    Item pop(string semantics=null)
    {
        debug{
            if (semantics is null)
            {
                stderr.writeln("<= [", stackPointer-1, "]");
            }
            else
            {
                stderr.writeln(semantics, " <= [", stackPointer-1, "]");
            }
        }
        auto item = stack[--stackPointer];
        return item;
    }
    Items pop(int count, string semantics=null)
    {
        return this.pop(cast(ulong)count, semantics);
    }
    Items pop(ulong count, string semantics=null)
    {
        Items items;
        foreach(i; 0..count)
        {
            items ~= pop(semantics);
        }
        return items;
    }
    void push(Item item)
    {
        debug{stderr.writeln(item.type, " => [", stackPointer, "]");}
        stack[stackPointer++] = item;
    }
    template push(T : int)
    {
        void push(T x)
        {
            return push(new IntegerAtom(x));
        }
    }
    template push(T : long)
    {
        void push(T x)
        {
            return push(new IntegerAtom(x));
        }
    }
    template push(T : float)
    {
        void push(T x)
        {
            return push(new FloatAtom(x));
        }
    }
    template push(T : bool)
    {
        void push(T x)
        {
            return push(new BooleanAtom(x));
        }
    }
    template push(T : string)
    {
        void push(T x)
        {
            return push(new String(x));
        }
    }

    bool isEmpty()
    {
        return stackPointer == 0;
    }

    override string toString()
    {
        if (stackPointer == 0) return "empty";
        return to!string(stack[0..stackPointer]);
    }
}
