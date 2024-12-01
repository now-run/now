![now logo](https://blog.cleber.solutions/upload/now-title.png)

Your code is ready. Now run.

## Rationale

Are you using *Make* as a command-runner for your
project? Or do you have a `bin/` directory with
*shell scripts*? Is your Makefile starting to feel
somewhat limited? Are your shell scripts escaping
from `bin/` and starting to feel pervasive in your
project?

It's very likely that you wished that you could have
the power of a good POSIX shell but wrapped in a simple
interface like that of Make.

Well, those are basically the problems `Now` wants to
solve. With `Now` you can write every supporting routines
of your project in only one file while still being able to
use all the power not only of a POSIX shell but of any
other tool available in your system in a well-organized
manner!

## Features

* REPL
* `Nowfile` (like a `Makefile`)
* Self-documenting command line interfaces
* Syntax for structured data
* Pipelines!
* System Commands
* Shells and Scripts (define external programs, like bash,
  and code that are expected to be run by them in your
  document/program)
* Load configuration from environment variables automatically
* Template System
* Data Sources (you can easily define procedures that
  load constants into your document before running it)
* Libraries implemented as external processes (no dynamic
  libraries / shared objects support required)
* Sections of your document can be simply text

## Install

### Using dub

To build Now, you must have `dub` installed.

On Debian-based Linux distros:

```bash
$ sudo apt-get install -y dub
```

On MacOS X:

```bash
$ brew install dub
```

Now you can run Now using `dub`, like in

```bash
$ dub run now -b release
```

but probably you'll want to run it directly, so I recommend
you create a symbolic link into some directory present in
your `$PATH`. In my case, I have a `~/bin` for that, so it
would be like this:

```bash
$ cd ~/bin
$ ln -sf ~/.dub/packages/now-$NOW_VERSION/now/dist/now now
```

Please notice you'll have to indicate the installed
version. If you want to automate that, you can use
`jq`:

```bash
$ NOW_VERSION=$(dub describe now | jq -rc '.packages[0].version')
$ cd ~/bin
$ ln -sf ~/.dub/packages/now-$NOW_VERSION/now/dist/now now
```

### Using make

- Have `ldc` installed (it's called `ldc2` on some systems);
- Have `make` installed;
- Clone the repository;
- `make release`;
- Symlink or copy `dist/now` to a directory under your `PATH`.

## Run

Considering there's a `Nowfile` in the current directory:

```bash
$ now <subcommand>
```

You can get a help text by calling `now` without arguments:

```bash
$ now
```

## Extras

In the `extras/` directory you'll find:

- A **vim syntax file**;
- A **bash completion function** (`source extras/completions/bash_now.sh`).

-----

## Syntax

```ini
[Sample Program]

Show the basics of the syntax

[commands/hello]
parameters {
    name {
        type string
        default "World"
    }
}

print "Hello, $name!"
```

Save it as `Nowfile` and run this in the same directory:

```bash
$ now hello
```

The idea of `Now` is to have a sort of **document**
containing everything your project need to be run in
each developer machine, tested or deployed, while still
being easy to read and understand.

That's why `Now` offers **commands**: they are what your
users (project developers, probably) are going to call
through the command line.

- The developer wants to run the project? `now run`
- Is it necessary to build it first? `now build`
- Changes were made? `now test`
- Tests passed and you want to make sure nobody is working
outside a feature branch? `now push`

## REPL

```bash
$ now :repl
```

If there's a `Nowfile` present in the current working directory,
it will be loaded and everything available inside any procedure
will also be available for you.

### Commands

```bash
$ now :cmd 'set x 10' 'print $x'
10
```

Sometimes it's useful to run a bunch of commands without having
to write that into a file, so you can do that using the `:cmd' option.

## More options

```bash
$ now :help
  No arguments: run ./Nowfile if present
  :bash-complete - shell autocompletion
  :cmd <command> - run commands passed as arguments
  :f <file> - run a specific file
  :repl - enter interactive mode
  :stdin - read a document from standard input
  :help - display this help message
```

## Integrating with bash

Just create a script for `bash` inside the "shells" key:

```ini
[shells/bash/scripts/run_server]
parameters {
    extra_args {
        type string
    }
}

source src/.env.dev
uvicorn app:server --host $HOST --port $PORT $extra_args
```

Then you can call `run_server` from inside your commands:

```ini
[commands/run_server]

run_server "--reload"
```

Notice that there's no name conflict in this case, because
**commands are not supposed to be called from inside your
document**. So there's actually only one "thing" that can
be called by the name `run_server`, and that is the bash
script we just defined.

## Integrating with external commands

External commands, or "system commands", are defined under
the "system_commands" key:

```ini
[system_commands/list_s3_objects]
parameters {
    bucket {
        type string
    }
    prefix {
        type string
    }
}
command {
    - aws
    - s3api
    - "list-objects"
    - "--bucket"
    - $bucket
    - "--prefix"
    - $prefix
}

[commands/ls]
parameters {
    prefix {
        type string
    }
}

list_s3_objects "default-bucket" $prefix 
    | collect
    | :: join "\n"
    | json.decode
    | :: get "Contents"
    | foreach item {
        print ($item . "Key")
    }
```

As you can see, the `list_s3_objects` system command is
being called by `ls` and its output is being passed through
a **pipeline** in order to print the key of each returned
object. Here we are using:

- `list_s3_objects` will return a SystemProcess, that yields `stdout` line-by-line;
- `collect` will receive each incoming line and turn they all into a single `List`;
- `join` **method** will join each item of this list as a string using "\n" as separator;
- `json.decode` will turn the JSON string into a `Dict`;
- `get` **method** will get the value of the key "Contents", that is a `List`;
- `foreach` iterates over the List;
- `print` will print to the standard output.
- `()` indicates we're using **infix notation**;
- `.` is the same as the method `get`, so `($a . b)` equals `obj $a | :: get b`.

## Procedures

The above command ended up big and tends to be
repeated in other places, so it's best to turn that into
a **procedure**.

Procedures are defined under the `procedures` key:

```ini
[procedures/s3_ls]
parameters {
    prefix {
        type string
    }
}

list_s3_objects "default-bucket" $prefix
    | collect
    | :: join "\n"
    | json.decode
    | :: get "Contents"
    | foreach item {
        print ($item . "Key")
    }
```

And now our `ls` command itself is much simpler:

```ini
[commands/ls]
parameters {
    prefix {
        type string
    }
}

s3_ls $prefix
```

## Events

Still, the system command `list_s3_objects` returning a
JSON string line-by-line is weird. We could improve that
by making everything more intuitive, like returning a
proper Dict "directly". In common programming languages
you'd probably wrap everything inside *yet another
procedure*, but Now offer you some **event handlers** for
each system command, procedure, shell script and even
commands:

- `on.call` - called after parsing arguments but before
  the "function" body;
- `on.return` - called right after the "function" returns;
- `on.error` - allows you to handle errors as you may find fit.

These handlers (except `on.error`) share the same scope as the body.

## User-friendly Commands

In order to use the auto-generated help text feature you
must add some information to your commands metadata,
namely: a `description` for the command and a `default`
for each parameter where it applies:

```ini
[commands/ls]
description "List objects inside default-bucket."
parameter {
    prefix {
        description "The prefix to be listed."
        type string
        default "projects/"
    }
}
```

Now, if the user types only `now` in the command line,
he will be greeted with something like this:

```bash
$ now
Sample Program
Show the basics of the syntax

 ls ----------> List objects inside default-bucket.
    prefix : string = projects/
```

## User-defined types

```ini
[types/server]
description "A mock of a server."
parameters {
    name {
        type string
    }
}

dict (status = stopped) (name = $name) | return

[types/server/methods/run]

o $self | set (status = running)

[commands/run]

server teste | as test_server
o $test_server | :: run
o $test_server | :: get status | :: eq running | :: assert "Status should be `running`"
```

## Properties

Values can have *properties*. They are set using the following syntax:

```ini
$object ~key1 value1 ~key2 value2 ~key3 value3...
```

For example:

```ini
set x 10 ~name ten ~name_pt dez
print $x  # 10
o $x | prop name | print  # ten
o $x | prop name_pt | print  # dez
```

## Why so much bureaucracy about "parameters"?

You may be asking **why** such a significant part of a
Now document is "wasted" with such lengthy parameters
definitions.

Well, think about most projects intended to be mantained
by more than one person and how the functions or methods
start very simple and then gain more and more complexity.

Like,

```python
def sum(a, b):
    return a + b
```

becomes

```python
def sum(a: int, b: int) -> int
    return a + b
```

and then

```python
def sum(a: int, b: int) -> int
    """Return the sum of two integers

    Parameters:
        a : int - the first term of the sum
        b : int - the second term of the sum

    Return:
        sum : int - the sum between a and b
    """
    return a + b
```

You see? In the end most projects leave behind the "just
define a function" approach in favor of this level or worse
of "documentation", type annotation, et cetera. And if you
are paying attention, you already realized that the typing
information is now present at two levels: one for the
computer, another for humans.

`Now` tries to avoid creating **syntax**, and it's always
a good thing to have one that is easily understandable
by both computers and humans, so we define parameters and
every kind of *metadata* in this simple format that,
although possibly a little bit lengthy, certainly avoid
any future mess, since it is quite easy to use it to
generate good documentation (as HTML, for example) while
still quite easy on the programmer's eyes (I decided to
not add the intuitive ` = ` symbol between keys and values
exactly because of that).

```ini
[procedures/sum]
description "Sum two integer numbers."
parameters {
    a {
        type int
        description "The first term."
    }
    b {
        type int
        description "The second term."
    }
}
return {
    type int
    description "The sum of a and b."
}

return ($a + $b)
```

## Configuration

```ini
[configuration/api]
protocol {
    default https
}
domain {
    default "example.org"
}
base_path {
    default "api/v1"
}
```

`now` has the ability to load configuration automatically from
**environment variables**. For the above definition, one should
define the `API_PROTOCOL`, `API_DOMAIN` and `API_BASE_PATH`
environment variables.

To access it in your scripts, use the `$api` Dict, like this:

```tcl
o $api | :: get protocol | print
# https
```

## Constants

```ini
[constants]
pi 3.1415
```

Constants are very similar to configuration, but they're not loaded
from any other place than their definition section. Besides, since
you are already giving their values, there's no need to inform
`default`, `type` or anything else.

## More Details About Syntax

### Header

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

### Body

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
- An InfixNotation;

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
implements an elegant way of writing things that fits better as
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
