---
title: The cost of many linting rules
date: '2022-08-31T12:00:00.000Z'
---

A few weeks ago, I released an article on ElmCraft figuring out how [ESLint's rules map to Elm](https://elmcraft.org/compare/javascript/eslint/).
To do this 

This was super enlightening

- Talk about ESLint comparison
- lots of rules: hard to configure
    - People use premade configurations
    - ESLint has a complex overriding system to make things work, while elm-review is just simple list of rules


Having many rules is not necessarily bad in itself. It can mean that there are many patterns that are problematic, but it can also mean that there are many of the bad patterns that can be detected by static analysis rules, which is a good thing. I don't expect a programming language to be perfect, or not simplifiable in any way past the point of compilation and doing the intended job. Therefore any tool that can help reduce the number of bad things to happen in a codebase we wish to put in production and maintain is a good thing.

Among the languages that I know well, the one that has the most issues is JavaScript.

Its ability to do many powerful but dangerous abstractions, to make operations implicit instead of explicit, while always being backwards compatible and never removing features that everybody frowns upon, all of these turn JavaScript into an environment favorable to the proliferation of bad patterns.

Back when I was a JavaScript developer, I wrote a lot of static analysis rules for JavaScript using ESLint... TODO

A bunch of these were meant for the Ava test framework.
TODO mention its a new environment and that we need to enforce new things again. Mention that other JS testing frameworks all have their own linting rules.
TODO check which one of these rules don't make sense in Elm.

TODO Separate blog post: alternative titles
- linters to the rescue of bad platforms
- Linters, the last frontier to bad code.

For every new sane environment you wish to create in JavaScript (for instance React), you will need static rules to remove all the bad things that can pollute this environment.

Example: function X should always return a value. Now you need a rule for that. Because you don't have a tool to ensure that as a general thing. I mean, you could have a rule that a function should never not return anything (and never return undefined), but since that would be way too general, that is not going to work without a lot of false positives, which we want to avoid as much as possible. Therefore, you add a rule to make sure that function X now properly returns a value. And you will do so for every function (or group thereof) that should definitely have the same behavior.

React tried to make a somewhat sane environment, with functional and declarative programming more or less at its roots, but because the framework can't have the guarantees that it would like to have, it will have to:
- do defensive programming: add lots of checks at the beginning of functions (`if (xyz !== undefined) {...}`). When these defensive checks fail, the framework will have to report comprehensive errors at runtime. These can have a performance cost in terms of execution speed and bundle size.
- write a lot of static analysis rules, to help developers use the framework as intended (https://github.com/jsx-eslint/eslint-plugin-react)

As Dillon talked about in (todo episode), a platform is created on top of another. JavaScript builds on top of the browser, React builds on top of JavaScript, some React sub-framework builds on top of React, etc. But because JavaScript is an unreliable platform, it is really hard to have it behave as expected.

TypeScript helps with the situation, but it does add some complexity overhead, and it doesn't help as much as authors would like, because types it not the only issue, and developers can use escape hatches (same for linters, unfortunately).

Unless the framework only supports TypeScript (like Angular?), it will have to support both, meaning the authors will have to do all the things I mentioned above anyway.

In my opinion, Elm provides a much more stable platform than JavaScript for frameworks. You have the guarantees that functions take and return what is specified by the framework. Functions can't arbitrarily crash by throwing executions. Users can't change the framework's environment by tampering with the core Elm functions, or by directly changing the framework's code.

For Elm's main framework, here are the only rules that I've found the need (or opportunity) to write: NoMissingSubscriptions which helps you remember to use a function that you should use. You also have NoRecursiveUpdate which reports about an antipattern that beginners sometimes try out that make the code harder to maintain later. Lastly, you have NoUselessSubscriptions, which is basically telling you about an opportunity to simplify your code.

Only the first one can really be a problem for the proper functioning (?) of the framework. Compare that with React where you have so many rules, that add on top of the core ESLint rules and those of additional ESLint plugins.


Linters are fantastic tools. They're very versatile, applicable in many situations and sometimes uniquely so, and they help make projects so much more maintainable. But because of their configurable nature, they should not be the first line of defense against bad code and problematic patterns. Yet they often are. Especially so in dynamic languages.

When the underlying language is not designed to have some basic guarantees, the tool can be very under-powered to catch the problems we would like it to catch.

But when the language is designed in a specific way, this becomes much easier. But even better is when the tool doesn't have to catch these problems because the underlying platform already does it in a more suitable way, or outright doesn't have the problem by the design of the platform.

There are other obvious benefits: easier to learn and bugs are less likely, both for newcomers and experienced developers.



---

All the semantic rules have to be re-written when they aren't enforced by a compiler or a type-checker.

But it's weird that you can choose the semantic errors that you'd want to enforce. And that you can ignore them when you want with a disable comment.

---

ESLint has a system to override configurations, which is used to handle the enormous amount of rules that are enabled and you may want to enable.

This system is very complex.

TODO figure out what the new flateslint configuration as about.
TODO see if other linters for dynamic languages have this kind of system (pylint, rubocup, ...)