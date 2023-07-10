# Example Document

This is a Now Document in Markdown format.

## Running

This section is an example of how an usual README file
would recommend running some commands on the shell.

If using Ubuntu:

```bash
$ apt-get install git
```

Or Gentoo:

```bash
$ emerge git
```

Or Void Linux:

```bash
$ xbps-install git
```

---

# Constants

* pi: 3.1415

# Configuration

## Hello

* salute: Hello
* who: World
* mark: !

# System Commands

## ls

- parameters:
  * directory:
    - description: The directory to be examined.
    - type: string
  * options:
    - type string
- command:
  * ls
  * -$options
  * $directory

# Procedures

## Sum

- parameters:
  * a:
    - description: The first parameter.
    - type: integer
  * b:
    - description: The second parameter.
    - type: integer
- return: integer

```now
return $a + $b
```


## Sum, but in Python

- parameters:
  * a:
    - description: The first parameter.
    - type: integer
  * b:
    - description: The second parameter.
    - type: integer
- return: integer

```python
return a + b
```

# Commands

## sum

- parameters:
  * a:
    - description: The first parameter.
    - type: integer
  * b:
    - description: The second parameter.
    - type: integer

```now
sum $a $b | print "sum is "
```
