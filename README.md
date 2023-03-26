![now logo](https://blog.cleber.solutions/upload/now-title.png)

Your code is ready. Now run.

-----

## Syntax

```tcl
[program]
name "Sample Program"
description "Show the basics of the syntax"


[commands/hello]
parameters {
    name {
        type strint
        default "World"
    }
}

print "Hello, ${name}!"
```

Save is as `program.now` and run this in the same directory:

```bash
$ now hello
```
-----

The document (or program) is divided into **sections** and each section
is comprised of a *section head* and its contents: the section *header*
and a *section body*.

That is:

```
  [head]
  header

  body
```

The body is separated from the header by an **empty line**.

## Header

The section header has a specific syntax, a little bit diffent from the syntax
for the body, but similar enough to not be confusing. This part ends with
a blank line and follows this format:

```
key value
```

The key must be a valid **atom**, that is:

- All lowercase;
- No special characters besides underscore (`_`) or dot (`.`).

And the value can be:

- A number (`123`, `12.34`);
- An atom (`hello`);
- A string (`"hey"`);
- A dict.

The syntax for dicts is as follows:

```
{
    key1 value2
    key2 value2
    ...
}
```

That is: it's a sequence of zero or many key/value pairs, **one by line**. A
value can be another dict, in which case it may extend for more lines.

```
{
    subdict {
        key value
        yet_another_subdict {
            another_key another_value
        }
    }
}
```

## Body

**The body of a section may or may not be Now code.**

Now code syntax is very similar to Tcl. Each code part of a section is
a `SubProgram`, and each SubProgram is comprised of a list of **Pipelines**,
in this format:

```
command1
command2 argument1
command3 argument1 argument2 argument3 etc
command4 | command5 | command6
```

Now each argument can be:

- A number, an atom or a string;
- Another SubProgram;
- An ExecList;
- An InfixList;

A SubProgram inside a SubProgram is enclosed by `{}`, like this:

```
scope "demonstrate a subprogram" {
    this is a subprogram
}
```

An ExecList is a way to run commands to create arguments to other commands. So
instead of relying on ad-hoc variables, you can run a command directly while
calling another one, like this:

```
print [list 1 2 3 4]
# (1 2 3 4)
```

`now` tries to minimize the ammount of *syntax* developers have to learn, so
instead of complicating the parser with lots of different symbols, it
implements a elegant way of writing things that fits better as
**infix notation**, like mathematical operations, comparisons, etc.

```
# This works. Notice that `+` has nothing special going on: it is
# simply a regular command:
set x [+ 1 2 3]
# 7

# If you like your program to be that *lispy*, okay. But if you don't:
set y (1 + 2 + 3)
```

What the parenthesis (`()`) do is to **rearrange the terms** so that they
fit the command-arguments pattern. In the above case, both operations are
effectually **the same**.
Not only that, but the parenthesis also group sequential equal operators, so:

```
set z (100 - 99 - 98 - 97 - 96 - 95)
```

is the same as

```
set z [- 100 99 98 97 96 95]
```

This way we can also operate over **dicts**:

```
# "Traditional" way:
print [get $program configuration hello salute_word]

# Infix notation way:
print ($program . configuration . hello . salute_word)

# (As you already realized, the above also could be written this way:)
# print [. $program configuration hello salute_word]
```

### Dicts

Speaking of dicts, the entire Program is actually read as a big dict. Each
section document part is a subdict and the code part goes to a special key
called "subprogram".

You can define a dict in two ways: using the `dict` command or using the
document syntax inside a special operator:

```
# Using the `dict` command:
set my_dict [dict (a = 1) (b = 2)]

# Using the well-known document syntax:
set my_other_dict <{
    a 1
    b 2
    s {
        x 10
        y 20
    }
}>
```

(I know I said `now` tries to minimize syntax, but it would be SO weird to
not have this alternative syntax available inside the code part...)

If you want to define a **list**, you can also use both ways: with the `list`
command or using the document syntax:

```
# Using the `list` command:
set lista [list alfa beta gama delta]

# Using the document syntax:
set listb <{
    - alfa
    - beta
    - gama
    - delta
>}
```

(Again, `now` try to minimize the ammount of syntax, so in a document, lists
are declared with the same syntax as dicts, only using a flag-key, `-`.)

You can access both dicts and lists elements using the command `get`:

```
get $lista 0  # the second element of the list
get $my_other_dict a  # the value of the key "a" of the dict
```

As said before, you can also use the `.` command, specially in conjunction
with the infix syntax:

```
print ($my_other_dict . s . x)
# The following would also work
print ($my_other_dict get s get x)
# But, yeah, it would seem VERY strange...
```

## Configuration

`now` has hte ability to load configuration automatically from
**environment variables**. So if you check the "configuration/hello"
part of this document, you'll see there's a key "salute_word". It
can be set via the environment variable `HELLO_SALUTE_WORD`.

(You can set default values, there, too.)

## Constants

Constants are very similar to configuration, but they're not loaded
from any other place than their definition section. Besides, since
you are already giving their values, there's no need to inform
`default`, `type` or anything else.

## Procedures versus commands

Procedures are code meant to be called by other parts of your code, while
commands (I mean, the code defined in `[commands/*]` sections) are
meant to be called from the command line. You cannot call a command from
inside your code.

Commands parameters definitions are used to auto-generate a **help text**
that is shown whenever you call `now` without a command name, while
procedures definitions are intended to both call validation, eventual
type coercion and auto-generate **documentation**.


-----


## Running

Considering there's a `program.now` in the current directory:

```bash
$ now <subcommand>
```

You can get a help text by calling `now` without arguments:

```bash
$ now
```

## Install

For now, no binaries are being released, but you can clone this repository
and run:

```bash
$ make
```

It's going to create a `dist/now`. I suggest you symlink it inside a directory
in your `PATH` (I have my `~/bin` for that).

You'll need `ldc` and `make` installed (`apt-get install build-essential` on
Debian or Ubuntu based distros).
