---
title: Removing an annoyance in elm-review-simplify
date: '2022-08-31T12:00:00.000Z'
---

I just released v2.0.19 of [`elm-review-simplify`](https://package.elm-lang.org/packages/jfmengels/elm-review-simplify/latest/), an `elm-review` package to simplify your Elm code (with over 150 different kinds of simplifications in its single rule).

Its simplifications aim to simplify your code without any drawbacks such as performance de-optimizations (usually the code will run faster if anything) or code style preference clashes.

Something that some people were complaining about was the fact the simplification for case expressions: when you had case expressions where every branch resulted in the same code (and no variables were extracted from the pattern), then it would be simplified like the following:

```elm
case x of
  A -> 1
  B -> 1
  C -> 1
-- simplified to simply
1
```

While this is a nice simplification in a lot of cases, it did remove a nice thing which was the compiler helping you out when you change the type. For instance, if you were to add a new variant, you would get a compiler error in the non-simplified version because the pattern become non-exhaustive, but no warning in the simplified version, which would be annoying when the value in this case should be something else than `1`.

This was also annoying when you only had a single constructor, like
```elm
doSomething x =
  case x of
    A -> 1
--> Simplify
doSomething x =
  1
--> NoUnused.Parameters
doSomething _ =
  1
```
You could replace this by
```elm
doSomething A =
  1
```
but this is currently invalid syntax in the IntelliJ IDE, so that makes for a bad experience.

---

So I changed the rule to now NOT simplify case of expressions where all the branches have the same code, when one of the patterns references a custom type from your project. For example:
```elm
case x of
  A -> 1
  B -> 1
  C -> 1
```
does not get simplified to `1` like before because it references `A`, `B` and `C` defined in your project. But the simplification still happens if the patterns only reference custom
types that come from dependencies (including `elm/core`), like:
```elm
case x of
  Just _ -> 1
  Nothing -> 1
--> 1
```

The reasoning is that often you want the compiler to give you a reminder when you introduce a new custom type (which this simplification made very hard), but custom types from dependencies very rarely change.

The configuration setting [`Simplify.ignoreCaseOfForTypes`](https://package.elm-lang.org/packages/jfmengels/elm-review-simplify/latest/Simplify#ignoreCaseOfForTypes)
now only takes custom types from dependencies. Any type provided to this function that is not found in the dependencies will now trigger a global error. It is likely that you won't need this function anymore. If you do, please open an issue because I'd love to know!

A number of `elm-review` users didn't use `Simplify` [because of the presence of the simplification above](https://github.com/jfmengels/elm-review-simplify/pull/45#issuecomment-1229161701), so I'm hoping that this change will make evaluate using the rule again. If there are more things that you find bothersome, please open an issue!

---

Additionally, thanks to [@miniBill] the rule now also simplifies record field accesses:
```elm
{ a = 1, b = 2 }.a
--> 1

{ foo | b = 1 }.a
--> foo.a
```

And the rule should be a bit smarter around deleting `if` expressions compared to what I wrote [a few days ago](/solving-annoyances/#testing-the-module-name-lookup-table), as the rule will now simplify code like the following:
```elm
if a == "a" then
  if a == "b" then -- always False
    1
  else
    2
else
  3
-->
if a == "a" then
  2
else
  3
```

and
```elm
if a /= "a" then
  if a == "a" then -- always False
    1
  else
    2
else
  3
-->
if a /= "a" then
  2
else
  3
```

[@miniBill]: https://github.com/miniBill
