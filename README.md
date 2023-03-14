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
        type str
        default "World"
    }
}

print "Hello, ${name}!"
```

Save is as `program.now` and run this in the same directory:

```bash
$ now hello
```


See [program.now](https://raw.githubusercontent.com/now-lang/now/main/program.now)
for more.

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
