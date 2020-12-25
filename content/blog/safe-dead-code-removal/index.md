---
title: Safe dead code removal in a pure functional language
date: '2020-10-25T12:00:00.000Z'
---

A few months ago, a colleague [wrote this](https://twitter.com/jfmengels/status/1311940821378387970) in Slack:

> Thanks to elm-review I was able to remove ~7300 lines of code in the front end in 225 different files.
> Something I could have never done without its aid. Thank you Jeroen!

Also some time ago, I [tweeted this](https://twitter.com/jfmengels/status/1330854406615674883):

> Just cleaned up a lot of Elm code. I wanted to remove our usage of a module that brought no value. Manually removed the main places where it was used and followed the compiler errors. That was about 200 lines.
> elm-review took care of the other 2700 lines of the then dead code.

For scale, this was on a project of about 170k lines of code. Well, before the code removal. If we take what my colleague did, he was basically able to remove ~5% of our entire codebase, while touching ~30% of all files.

And **we felt good** about that.

I wanted to go through how [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/), a static analysis tool for [Elm](https://elm-lang.org/), was able to help us with these big changes that we were very confident with. Spoiler: It's because of the lack of side-effects in the language.

### Obscurity by impurity

I'll take the examples of JavaScript because that's another language for which I worked a lot on static analysis.

```js
function formatUserName(user) {
  const middleNames = formatMiddleNames(user)
  return user.name.first + ' ' + user.name.last.toUpperCase()
}
```

If you wanted to clean up the JavaScript code above, the only thing you'd be able to do automatically and safely is remove the assignment of `formatMiddleNames(value)` to `middleNames`, as shown below.

```js
function formatUserName(user) {
  formatMiddleNames(user)
  return user.name.first + ' ' + user.name.last.toUpperCase()
}
```

We can't remove the call to `formatMiddleNames(value)` because we don't know if it has side-effects. Maybe it is a pure function that just creates a value and doesn't interact with global variables. Or maybe it is an impure function since it mutates the `user` argument or global variables, makes HTTP requests, etc. I can _reasonably_ imagine that `formatMiddleNames` takes something like `user.name.middleNames` and appends it to `user.name.first` by mutating it.

If it is impure, then removing it would change the behavior of the code in an unexpected way. Without knowing whether it is pure or impure, we can't safely remove it.

If your static analysis tool is sufficiently powerful, you could inspect `formatMiddleNames` to see if it has side-effects, but that might end up being a rabbit hole: the tool would have to check whether the functions or parameters used inside somehow cause side-effects themselves. Sometimes it will even have to analyze the contents of your dependencies, where I _think_ most static analysis tools stop.

### Clarity by purity

In Elm, you only have **pure** functions. Meaning that there is no observable difference between calling a function and not using the result, and not calling it at all.

In Elm, the previous uncleaned code snippet would translate to this:

```elm
formatUserName user =
  let
    middleNames = formatMiddleNames user
  in
  user.name.first ++ " " ++ String.toUpper user.name.last
```

Here we could **safely** — without changing the behavior of the program — report that the whole declaration of `middleNames` can be removed, `formatMiddleNames(value)` included. This might be a mistake on the part of the user because they might have wanted wanted to use `middleNames` but forgot to, so when `elm-review` analyzes your code and it has been run with `--fix`, it will ask the user for confirmation before applying the fix automatically. Every `elm-review` fix proposal requires an approval from the user before it gets committed to the file system. There is a way to batch them to avoid having the process be too tedious though, which I find people start to use after the tool has gained their trust.

```elm
formatUserName user =
  user.name.first ++ " " ++ String.toUpper user.name.last
```

TODO Add a screenshot

In the rest of the article, I will refer to what we did here as step 1.

### What more can we find?

#### Step 2

In JavaScript, we would have had to keep the call to `formatMiddleNames`, but in Elm-land, we were able to remove it. That allows us to do one more thing: check whether `formatMiddleNames` is ever used anywhere.

```elm
module SomeModule exposing (formatUserName, thing)

import OtherModule

thing =
  formatUserName 2

formatUserName user =
  user.name.first ++ " " ++ String.toUpper user.name.last

formatMiddleNames user =
  OtherModule.doSomething value
```

When we look at this module, it seems that `formatMiddleNames` is never used in any way. So we can safely remove it too!

TODO Screenshot

#### Step 3

Now removed `formatMiddleNames` was using a function from module `OtherModule`. And that was the last usage of that import.

In JavaScript, importing a module can cause side-effects. Meaning that to be safe, we could only remove from the import declaration the assignment to a name.

```js
import defaultExport from 'module-name'
// -->
import 'module-name'
```

In Elm, importing a module is free of side-effects. Meaning that we can remove the whole import.

```elm
module SomeModule exposing (formatUserName, thing)

import OtherModule
-->
module SomeModule exposing (formatUserName, thing)
```

TODO Screenshot

#### Step 4

(This would have been reported at the same time as step 3)
Let's look at `OtherModule`.

```elm
module OtherModule exposing (CustomType, doSomething, finalThing, otherThing)

import ThirdModule

type CustomType
  = CustomTypeVariant1 Int
  | CustomTypeVariant2 Int

otherThing value =
  CustomTypeVariant1 value

doSomething value =
  CustomTypeVariant2 (ThirdModule.blabla value)

finalThing customType =
  case customType of
    CustomTypeVariant1 value -> String.fromInt value
    CustomTypeVariant2 value -> String.fromInt -value
```

`elm-review` rules have the ability to look at multiple/all modules of a project before reporting errors. This makes the tool immensively more powerful than ones that only look at a single module, and allows us to report things about a module based on how it used in other modules.

In this case, a different rule named [`NoUnused.Exports`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports) will report that `doSomething` is exposed as part of the module's API but never used in other modules, as `SomeModule.formatMiddleNames` was the only location where it was used in our example. Since it's not used anywhere in the project outside of this module, we can safely stop exposing it from the module.

Note that if this was some kind of utility module that you wanted to keep as is, you could disable this particular rule for that file. This rule does not report functions exposed as part of the public API of an Elm package, no worries there.

```elm
module SomeModule exposing (CustomType, doSomething, finalThing, otherThing)
-->
module SomeModule exposing (CustomType, finalThing, otherThing)
```

TODO Screenshot

#### Step 5

Now it looks like `doSomething` was not used internally in `OtherModule` either, so we can remove it entirely just like we did for `formatMiddleNames`.

TODO Screenshot

#### Step 6

`doSomething` was using the `CustomTypeVariant2` variant of `CustomType` and that was the only location where it was ever created. If that variant is never created, we have no need to handle it.

For those not familiar with union types or algebraic data types but familiar with JavaScript, a custom type allows you to switch statements but where the compiler checks whether you've handled all the possible cases.

```js
function finalThing(customType) {
  switch (customType.type) {
    case "CustomTypeVariant1": return customType.value.toString()
    case "CustomTypeVariant2": return (-customType.value).toString()
    default: // No need for this in Elm
}
```

This is the first case where an automatic fix is not offered, because we will need to remove the variant both in the custom type definition and in the different patterns. In this case, it's safer to let the user remove the definition themselves and let the Elm compiler help them fix all the compiler errors that causes.

```elm
module SomeModule exposing (CustomType, finalThing, otherThing)

import ThirdModule

type CustomType
  = CustomTypeVariant1 Int

otherThing value =
  CustomTypeVariant1 value

finalThing customType =
  case customType of
    CustomTypeVariant1 value -> String.fromInt value
```

TODO Screenshot

TODO Remove this?
Now that there is only a single variant for `CustomType`, we could probably go one step further and try to simplify `finalThing` by destructuring in the arguments. But this is a stylistic issue since both have the same behavior, and there is at the moment of writing no rule for this.

```elm
finalThing (CustomTypeVariant1 value) =
  String.fromInt value
```

#### Step 7

(This would have been reported at the same time as step 6)
Once again, we have an unused import `ThirdModule` that we can safely, as the only place it was used in was `doSomething`.

TODO Screenshot

#### Step 8

[`NoUnused.Modules`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Modules) tells us that `ThirdModule` is actually never imported anywhere

TODO More steps:

- Declaring a module as unused
- Unused export
- Unused custom type constructors

### Recap

Let's do a comparison of our code before and after `elm-review`.

#### Before

```elm
module SomeModule exposing (formatUserName, thing)

import OtherModule

thing =
  formatUserName 2

formatUserName user =
  let
    middleNames = formatMiddleNames user
  in
  user.name.first ++ " " ++ String.toUpper user.name.last

formatMiddleNames user =
  OtherModule.doSomething value
```

```elm
module OtherModule exposing (CustomType, doSomething, finalThing, otherThing)

import ThirdModule

type CustomType
  = CustomTypeVariant1 Int
  | CustomTypeVariant2 Int

otherThing value =
  CustomTypeVariant1 value

doSomething value =
  CustomTypeVariant2 (ThirdModule.blabla value)

finalThing customType =
  case customType of
    CustomTypeVariant1 value -> String.fromInt value
    CustomTypeVariant2 value -> String.fromInt -value
```

```elm
module ThirdModule exposing (blabla)
-- ...
```

#### After

```elm
module SomeModule exposing (formatUserName, thing)

import OtherModule

thing =
  formatUserName 2

formatUserName user =
  value + 1
```

```elm
module OtherModule exposing (CustomType, finalThing, otherThing)

import ThirdModule

type CustomType
  = CustomTypeVariant1 Int

otherThing value =
  CustomTypeVariant1 value

finalThing customType =
  case customType of
    CustomTypeVariant1 value -> String.fromInt value
```

### The wonky Jenga tower

I like to think of this (TODO) as a wonky Jenga tower effect, where parts of the codebase fall off when they become unused. The more blocks you remove, the more it will become shaky until ultimately some blocks will want to fall off.

We were able to remove all of this code because we were able to remove a let variable that was holding all the other blocks together. Had we left it there, the tower would remain standing.

Without the guarantees of a **pure functional language**, or more precisely the knowledge of whether a function has side-effects, we could not have discovered as much. An impure language makes the blocks all muddy and sticky, hard to remove. A pure language makes the blocks all smooth, easily removable by a flick of a finger.

I know that few of these steps would have been reported by [ESLint](https://eslint.org/) (a static analysis tool for JavaScript) because it can't **safely** remove function calls, property accesses and imports that have potential side-effects, and because it can only look at one module in isolation (a current limitation of the tool).

`ESLint` would only have been able to report the things reported at steps 1 (partially, only the assignment part), 2 and 5, but in practice it would have stayed stuck after step 1, and that would be true for I think any programming language except pure functional languages. Unless the tool does very extensive checking, in which case you should go thank the maintainers for their great work!

Before I started writing this blog post, I believed `ESLint` would automatically fix the error at step 1, but it turns out it doesn't and stops at simply reporting it. Considering that `ESLint`'s fix feature applies all fixes silently until no more could be found, that makes it hard to stop at any given step to use a function that should have been used somewhere instead of deleting it. The other JavaScript linters I could find (JSHint, JSLint, RSLint) don't have an automatic fix feature, meaning that no JavaScript linter currently removes dead code for you. And that's probably for the better.

### YAGNI (You Aren't Gonna Need It)

Even when code feels safe to remove, you can feel like you should keep some unused code, just in case it will be used later. As I said, you can somewhat ignore these rules on select pieces of your codebase, but apart from isolated utility functions (potentially), I would remove it.

I have started embracing YAGNI (You Aren't Gonna Need It) and removing everything, knowing that I have a Git history "just in case" and knowing that the code I could have kept may not even fit the needs of the situation I'm keeping it for.

I have been doing [a](https://twitter.com/jfmengels/status/1336567810793893889) [lot](https://twitter.com/jfmengels/status/1337803716737560577) [of](https://twitter.com/jfmengels/status/1337805942029774851) [work](https://twitter.com/jfmengels/status/1337910280953716738) recently to find more and more dead code in Elm, for instance by discovering unused functions in code paths that can't ever be reached. These will in practice rarely find things to remove (compared to the the simpler checks I was already doing).

Is it useful for you to be pedantic about deleting potentially useful code and for me to chase after dead code so much? I would love to say it is not, but as we saw in this example, it is only because we were so pedantic (on removing even let variables) that we were even able to start this process. Maybe by removing this last bit of dead code, we will remove the last block holding up a bigger part together.

I wouldn't spend much time working trying to find dead code manually, but since we have tools to do this automatically and in very reasonable amounts of time, I find the cost to be quite low. I leave the value of having less code (and less complex code) to maintain up to your appreciation (or for a future post).

Marie Kondo says that if something doesn't bring you joy, you should throw it away. In my case, after I do refactor some code, I run `elm-review` and hope that it will start finding things to throw away. As Martin Janiczek [says](https://twitter.com/janiczek/status/1330940781083947008):

> It's such a joy to be reminded by elm-review that you can now delete some dead code!

Always leave your codebase cleaner than you found it. Especially when that becomes easy.