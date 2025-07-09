---
title: Essential and accidental configuration
slug: essential-and-accidental-configuration
published: "2025-07-10"
---

As a tool author, I try to make my tool as simple to use and easy to configure as possible. Taking example from [essential and accidental complexity](https://en.wikipedia.org/wiki/No_Silver_Bullet#%3A%7E%3Atext%3DAccidental_complexity_relates_to_problems%2Csources_of_accidental_complexity_remain.?wprov=sfla1) (of which I'll take excerpts), I will here introduce essential and accidental configuration.

## Essential configuration

> Essential **complexity** is caused by the problem to be solved, and nothing can remove it; if users want a program to do 30 different things, then those 30 things are essential and the program must do those 30 different things.

Essential **configuration** is how the user tells the tool what they want. If the program can do 30 different things a user may want from the tool, then the essential configuration is what determines which one(s) should be chosen.

It is likely the kind of configuration that you're thinking of when you think of the term "configuration".

Essential configuration is necessary, though if the tool only does one thing, there may be none.

Say a user wants to list all the files in a folder, they can use the `ls` bash command which accepts an optional list of folders paths. The user can leave this list empty to display the contents of the current folder, or specify a list of them to display the contents of other folders.

```sh
$ ls
file1 file2 file3 file4
file5 file6 file7 file8

$ ls folder/
file9 file10
```

They can then use a number of other options to indicate how they want the contents to be displayed: on a single or several lines, with the file sizes and permissions, with or without colors, etc.

```sh
$ ls -l -s
total 388
  4 drwxrwxr-x 4 user user 4096 Apr 2 12:13 file1
380 -rw-rw-r-- 1 user user 388244 Aug 19 16:59 file2
  4 -rw-rw-r-- 1 user user 849 Jul 6 22:55 file3
```

These are all essential configuration. It is not a matter of being optional or mandatory - that is entirely orthogonal - only a matter of whether they relate to what the user wants to do with the tool and with what it should output.

Some other examples:
- You're using a code optimizer, and you tell it which optimizations to enable.
- You're using a build tool, and you tell it where to output the result and in what format.
- You're using a linter, and you tell it which kinds of problems you want it to report.

Whatever options the user chooses, the tool will give a correct answer back (bugs and invalid configuration notwithstanding). The user may find that the result does not suit their expectations and decide to alter the configuration, but the results are correct nonetheless.

Say you have a linter that you configured as such:

```json
{
  "rules": [
    "no-unused-vars",
    "no-goto",
    // ...
  ]
}
```

The list of rules is essential configuration: they indicate what the user wants the linter to do, which rules to enable.

The linter will report on what it is configured to report. Users may or may not like the results and the rules they enabled, and they can re-configure accordingly.

## Accidental configuration

> Accidental **complexity** relates to problems that engineers create and can fix.

Accidental **configuration** is the information (that is not essential configuration and) that a user needs to **correctly** provide to the tool in order for the tool to yield correct results.

Say in the linter configuration we add a `languageVersion` field.

```json
{
  "languageVersion": 2,
  "rules": [ ... ]
}
```

`languageVersion` is accidental configuration. It is meant to **reflect an information about the project**, and the tool will change its behavior based on this value.

For instance, if you're using Python 2, then the linter will parse `print "Hi"` as correct code, but if you're using Python 3 then it will consider it as a syntax error (it should be `print("Hi")`).

If it turns out that the accidental configuration is incorrect (for instance, you configured the `languageVersion` to be 2 but you're using version 3), then the tool may not work correctly or at all, and it may be hard to figure out why you're getting incorrect results or an error code.

## Accidental configuration causes confusion

Accidental configuration can be a source of hard-to-understand errors and of confusion. It is often hard to solve, especially for people with no prior experience with the tool or its results, because the problem will be elsewhere.

A tool will have a hard time verifying that the user was mistaken somewhere in their configuration as it will usually trust whatever information is provided, and therefore it's unlikely to tell the user to change the configuration. Especially if the output seems valid from the tool's perspective.

A user could rightfully believe that the software has a bug, even though they were the one to misconfigure the tool.

This leads users to ask questions on support forums or to look at the docs. But the docs will rarely explicitly tell them the link between some problem that was encountered and a misconfiguration (or which particular bit was incorrect).

"If this option is misconfigured, then you might get errors/results such as..." is a rather rare statement in documentation, and one you'd more often see in a support or StackOverflow thread.

If the maintainers of the tool know about this problem, then when possible it would be best to fix the issue, or provide in-tool feedback rather than specify it in the documentation (both in-tool feedback and documentation could be even better).

## Optional accidental configuration

Some tools set default values for accidental configuration.

Considering that Python 3 was released in 2008, it would make sense for a Python tool to make `languageVersion` default to `3`. But if you're using version 2, then you will likely get failures or incorrect results.

You as a user will then have to scour the documentation and support forums to find out the solution, and notice that you need to specify a new option with a specific value.

I personally find tools with optional accidental configuration to be really hard to use, as it makes onboarding really difficult.

## (How to) avoid accidental configuration

Accidental configuration is something to avoid as much as possible, though it may be hard to do so.

I consider it to be a problem (or at least a smell) if some information that a tool needs (as optional or required configuration) is requested while it's available somewhere else (cheaply and reliably).

Let's say we create a new `ls` command that takes a directory path and prints all the files in that directory. You could be running it on a Unix or a Windows machine that respectively use `/` or `\` as folder separators.

But how would it know which separator needs to be used on the current platform? Well we can add a `--path=windows` / `--path=unix` argument to the tool.

```sh
> new-ls --path=windows some\path
file1.txt file2.txt ...

> new-ls --path=windows some/path
Invalid path!
```

This sounds ridiculous. Obviously, the tool should be able to detect the environment on its own (and/or convert the path in a way that it will understand regardless of the operating system).

So that's the best solution: **auto-detection**.

In general, either data is fetched by the tool somehow, or it is provided by the user (through CLI arguments, the dedicated configuration file, etc.). If it gets provided by the user, then there is a bigger chance for it to be incorrect, or become incorrect if it needs to stay in sync with some other data.

In this `ls` example, the accidental configuration can be replaced by auto-discovering the environment. But for many other use-cases, necessary information will be elsewhere.

Let's again take the linter and `languageVersion` example from before. Let's say that in the language you're using, there is always a `manifest.json`, that contains that exact same information (and more).

```json
{
	"languageVersion": 3
}
```

Now, considering that there's already a file with this information, in a reliable and stable location, it feels odd to have the linter also ask this information in its configuration. Instead, it should read directly from `manifest.json`, making it the single source of truth.

That way, the day that the language version is bumped, it only needs to be done in one place, which avoids problems caused by inconsistent information (that you would get if you had the data duplicated but only changed one of them).

Sometimes this file doesn't exist in an ecosystem of tools. But then, maybe it makes sense to try to push for such a file (or that data) to exist in a standard way.

Just to be clear, having auto-detection doesn't mean that a tool shouldn't support overriding it, as that might be useful in some situations, or as it may enable new use-cases for the tool.

## Summary

Essential configuration is to make the tool do what you want.

Accidental configuration is to make the tool work for your project or situation, and should be avoided as much as possible, primarily through auto-detection (or the reducing of features) to reduce the number of sources of truth.

I mostly talked about tools, but this idea applies to other aspects as well, such as programming APIs or HTTP APIs. I hope we will all see less and less of them.