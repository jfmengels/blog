---
title: Removing unused parameters, and then some
slug: removing-unused-parameters
published: "2025-12-30"
---

Today is a mass release of `elm-review` packages.
The highlights: the introduction of best-in-class unused parameter **automatic fixing**,
a lot of improvements in other rules and packages under my name, and `Simplify` got a **massive** list of new simplifications.

### [`NoUnused.Parameters`]

This rule — which detects unused parameters — has up until now had (barely) no automatic fixes, the reason being
that the only automatic fix that felt possible was to replace an unused parameter by `_`,
which is how in Elm you would legitimately ignore a parameter.

```elm
-- Before
someFunction unused used =
   doSomethingWith used

-- After
someFunction _ used =
   doSomethingWith used
```

But that would also be the last time the rule would be able to tell you about an unused parameter.
So if the rule were to autofix it, then you would never notice you could remove the parameter yourself.
We'd lose a golden opportunity to improve the code.

```elm
-- Before
someFunction : Int -> Int -> Something
someFunction unused used =
   doSomethingWith used

value =
  someFunction 1 2

-- After
someFunction : Int -> Something
someFunction used =
   doSomethingWith used

value =
  someFunction 2
```

In today's release, `NoUnused.Parameters` gains the ability to remove arguments automatically, both in its declaration, signature, **and where it gets called**.
Given the previous example's "before", you would get the "After" result.

And thanks to the previous `elm-review` release where we introduced [multi-files fixes](/multi-file-fixes),
this fix also happens even if the function is exposed and **referenced in other modules!**

```ansi
[38;2;51;187;200m-- ELM-REVIEW ERROR ------------------------------ src/Article.elm:15:16[39m

[38;2;255;0;0mNoUnused.Parameters[39m: Parameter `cred` is not used

14|     -> Html msg
15| favoriteButton cred used =
                    [38;2;255;0;0m^[39m
16|     -- some implementation

You should either use this parameter somewhere, or remove it at the
location I pointed at.

[38;2;51;187;200mI think I can fix this. Here is my proposal:[39m

[38;2;51;187;200m1/3 ---------------------------------------------------- src/Article.elm[39m

 9| favoriteButton :
[38;2;255;0;0m10|     Cred
11|     -> msg
[38;2;0;128;0m +|     msg[39m
12|     -> List (Attribute msg)
13|     -> List (Html msg)
14|     -> Html msg
[38;2;255;0;0m15| favoriteButton _ msg attrs kids =[39m
[38;2;0;128;0m +| favoriteButton msg attrs kids =[39m
16|     -- some implementation

[38;2;51;187;200m2/3 ----------------------------------------------- src/Article/Feed.elm[39m

120|    else
[38;2;255;0;0m121|        Article.favoriteButton cred onClick[39m
[38;2;0;128;0m  +|        Article.favoriteButton onClick[39m

[38;2;51;187;200m3/3 ----------------------------------------------- src/Page/Article.elm[39m

569|    else
[38;2;255;0;0m570|        Article.favoriteButton cred onClick [] kids[39m
[38;2;0;128;0m  +|        Article.favoriteButton onClick [] kids[39m
571|

[?25l[2K[1G[36m?[39m [1mDo you wish to apply this fix?[22m [90m›[39m [90m(Y/n)
```

If the argument is `_`, and the rule determines it can be fixed, that means that there is no good reason
(such as conforming to a type signature) to keep it around. Therefore, we now report `_` if and only if it's deemed fixable.

```ansi
[38;2;51;187;200m-- ELM-REVIEW ERROR ------------------------------ src/Article.elm:15:16[39m

[38;2;51;187;200m(fix) [39m[38;2;255;0;0mNoUnused.Parameters[39m: Parameter `_` is not used

14|     -> Html msg
15| favoriteButton _ msg attrs kids =
                   [38;2;255;0;0m^[39m
16|     -- some implementation

You should either use this parameter somewhere, or remove it at the
location I pointed at.

[38;2;51;187;200mErrors marked with (fix) can be fixed automatically
using `elm-review --fix`.[39m
```

That's not all! We also remove unused fields from literal record arguments:

```ansi
[38;2;51;187;200m-- ELM-REVIEW ERROR ------------------------------------ src/Foo.elm:4:7[39m

[38;2;255;0;0mNoUnused.Parameters[39m: Parameter `unused` is not used

3| foo : { unused : a, used : b } -> b
4| foo { unused, used } =
         [38;2;255;0;0m^^^^^^[39m
5|     fn used

You should either use this parameter somewhere, or remove it at the
location I pointed at.

[38;2;51;187;200mI think I can fix this. Here is my proposal:[39m

 2|
[38;2;255;0;0m 3| foo : { unused : a, used : b } -> b[39m
[38;2;255;0;0m 4| foo { unused, used } =[39m
[38;2;0;128;0m +| foo : { used : b } -> b[39m
[38;2;0;128;0m +| foo { used } =[39m
 5|     fn used
···
10| a =
[38;2;255;0;0m11|     foo { unused = 1, used = 2 }[39m
[38;2;0;128;0m +|     foo { used = 2 }[39m
```

And similarly for tuple values.

And no, we don't remove fields from type aliases yet, that would have to be a new rule (it's in the plans... though it's been that way for years).

The last thing is that the rule now also removes unnecessary aliases.

```ansi
4| add ({ a, b } as unused) =
                    [38;2;255;0;0m^^^^^^[39m
5|     a + b
...
[38;2;51;187;200mI think I can fix this. Here is my proposal:[39m

[38;2;255;0;0m4| add ({ a, b } as unused) =[39m
[38;2;0;128;0m+| add ({ a, b }) =[39m
5|     a + b
```

`elm-review-unused`'s rules remove so much code automatically that it always felt annoying to have to remove
the unused parameters afterwards, especially when an argument is passed through many layers of functions.
Not having to do this anymore will feel **glorious**.

I am not aware of any other linter that removes unused parameters automatically, or remotely close to the same extent.
This is [*once again*](/safe-dead-code-removal) a safe change only because Elm doesn't have side-effects. A rather important reason
for not removing an argument is because it may remove a side-effect, changing the behavior of the program.

```js
someFunction(sideEffect(), 2)
```

Analysis can be done to remove at least the trivial cases where an argument is without effects, but there will be a knowability
limit when side-effects are possible. That's not the case for Elm, so we make the most of it.


### More from `jfmengels/elm-review-unused`


- Fixed an issue for [`NoUnused.Exports`] where a custom type did not get reported when one of its constructors was named like another type.
In the following example, type `Unused` was incorrectly considered as used:
```elm
type alias T = ()
type Unused = T
value : T
value = ()
```
- [`NoUnused.Exports`] now reports (and fixes) unnecessary exposing of a custom type's variants in a module's `exposing` list.
```diff
-module A exposing (Type(..))
+module A exposing (Type)
```
- [`NoUnused.Variables`] now reports (and fixes) unnecessary imports to functions/types available by default (`Basics`, `List`, etc.)
- [`NoUnused.Dependencies`] now doesn't report `elm/json` as an unused dependency for applications (as not depending on it yields compiler errors).
- [`NoUnused.CustomTypeConstructors`] now gives a hint in its error message on how to not have phantom errors reported.


### jfmengels/elm-review

#### Ignoring fixes

In [Multi-files fixes](/multi-file-fixes), I announced that [`NoUnused.CustomTypeConstructors`] supported files across
multiple files. One thing I didn't anticipate, which some people reported, and became even more obvious with the
previously mentioned change to `NoUnused.Parameters`, is that ignored files would sometimes be modified by these multi-file fixes.
This would be most annoying when those files are generated, and when a compiler error would show up when re-generating
them.

I made several changes to improve this:
- [`Review.Rule.ignoreFixesFor`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#ignoreFixesFor)
was introduced to specify which files are not fixable, i.e. that an automatic fix should be ignored completely if it touches one of the listed files.
```elm
config =
    [ Some.Rule.rule
        |> Rule.ignoreFixesFor
            [ FilePattern.exclude "src/Some/File.elm"
            , FilePattern.exclude "src/Folder/**/*.elm"
            ]
    ]
```

- Files that are ignored (`Rule.ignoreErrors*` functions) are considered as not fixable.
- Through [`Review.Rule.ignoreFixesFor`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withIsFileFixable),
rules can be made aware of which files are not fixable, allowing them to change their behavior if needed.

#### Glob ignores

I added [`Review.Rule.ignoreErrorsFor`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#ignoreErrorsFor)
as an alternative to `ignoreErrorsForDirectories` / `ignoreErrorsForErrors` / `filterErrorsForFiles` to be able to specify ignores using Glob patterns.

```elm
Some.Rule.rule
    |> Rule.ignoreErrorsFor
        [ FilePattern.exclude "src/Folder/**/Example.elm"
        ]
```

### elm-review-common

#### NoPrematureLetComputation

I worked quite a bit on improving [`NoPrematureLetComputation`].

It can now move let declarations whose pattern introduces multiple values.
In the example below, only (1) could get moved, but with this update (2) can get moved as well.
```elm
-- (1)
let
  { x } = value
in
some code

-- (2)
let
  { x, y } = value
in
some code
```

It can now move let declarations that have names in their scope.
This was previously purposefully reported but not automatically fixed, as moving a declaration could introduce compiler errors about shadowing.

```elm
let
  fn a =
    a
in
case value of
  Just a ->
    fn a
  Nothing ->
    Nothing
-->
case value of
  Just a ->
    let
      fn a = -- ERROR: `a` is already defined two lines above
        a
    in
    fn a
  Nothing ->
    Nothing
```
We now detect whether such a compiler error would occur and only prevent the fix in that case.

The rule can now also move a let declaration inside `Tuple.mapBoth` functions.

A lot of work has been done to preserve comments when moving code around. Previously, losing comments would be fairly common.
The more precise fixes are also prettier, making them easier to view in the fix prompt diff.

I also corrected an automatic fix that resulted in incorrect syntax. Since `elm-review` checks the result of the fixes,
you would only notice this as an automatic fix that couldn't be applied.

#### NoDeprecated

- [`NoDeprecated`] now includes the deprecation message in the error details [when one can be found](https://package.elm-lang.org/packages/jfmengels/elm-review-common/1.3.5/NoDeprecated#tagging-recommendations).

```elm
{-| Rough value for π.
@deprecated Use piPrecise instead which is more precise.
-}
pi = 3.14

{-| Somewhat precise value for π. -}
piPrecise = 3.14159
```

```ansi
[38;2;255;0;0mNoDeprecated[39m: Found new usage of deprecated element

20| value =
21|     pi
        [38;2;255;0;0m^^[39m

This element was marked as deprecated and should not be used anymore.

Deprecation: Use piPrecise instead which is more precise.
```

### CLI

- Fixed errors being displayed twice when target files are both part of the project and of extra files.
- When building the review application, `elm-review` will now respect the specific versions of indirect dependencies listed in the review configuration's `elm.json` file.
- Improved error message when using `--config` with a path to a file (instead of a directory).
- Added `--elmjson` and `--config` to the help text for `prepare-offline`.
- Made it so `prepare-offline` also downloads dependency data to avoid different results when running with or without `--offline`.
- Fixed an issue where relative `ELM_HOME` would not be respected when building the review application (and would instead be located somewhere under `elm-stuff/`).
- Fixed `new-package` subcommand crashing on Nix.

### [`Simplify`]

A **lot** of work was done on `Simplify`, most of which by [@lue](https://github.com/lue-bird) (as has been for many releases).

To start off, we *removed* a `List.concat` simplification to improve quality of life:
```elm
grid =
    List.concat
        [ [ O, X, X ]
        , [ O, O, X ]
        , [ X, O, O ]
        ]
--> previously
grid =
    [ O, X, X, O, O, X, X, O, O ]
```
This simplification, in conjunction with `elm-format`, made it sometimes harder to understand the data, and is therefore getting removed.
It will however still apply when there doesn't seem to be any structure, i.e. when the list is on one line or when all sub-items are on different lines.
`[ 1, 2 ] ++ [ 3, 4 ]` has also partially been disabled with similar logic.

Bug fixes:
- Simplifying directly applied lambdas doesn't remove extra arguments. `(\_ a -> ...) b c` is now simplified to `(\a -> ...) c` instead of `(\a -> ...)`.
- Some lambdas like `\a -> f a a` were incorrectly treated like they could be reduced to `f a`, leading to rare bugs when composing for example `(\n -> List.repeat n n) >> List.sort`

Some detection improvements:
- Now recognizes more lambdas as "equivalent to identity",
  to catch issues like `Maybe.map (\(x, y) -> (x, y))`
- Now evaluates `<`, `<=`, `>=`, `>` for any two comparable operands to for example fix `"a" < "b"` to `True`
- Now fixes `Tuple.first (Tuple.mapBoth changeFirst changeSecond tuple)` to `changeFirst (Tuple.first tuple)` instead of `Tuple.first (Tuple.mapFirst changeFirst tuple)` (same for second)
- Now recognizes more lambdas as equivalent, to for example detect equal branches like `if c then f else \a -> f a`
- Now recognizes more `if`s as equal or different,
  to for example fix `(if c then 2 else 3) == (if c then 1 else 4)` to `False`

On this last change: I just love how sophisticated this rule has become, to figure out things that would be hard for even developers to notice.
In its [documentation](https://package.elm-lang.org/packages/jfmengels/elm-review-simplify/latest/Simplify#simplifications),
we list **over 500** simplifications. But these listed simplifications are **summaries** of what's detected.

An example of that, which I immediately loved when I first saw it in the tests, is this (new) simplification:

```elm
Dict.foldr (\key value list -> ( key, value ) :: list) [] dict
--> Dict.toList dict
```

That is literally the implementation of `Dict.toList`. It's not the easiest to detect, but it's the most straightforward version of the change. 
The version I saw in the tests however — and which was also simplified to `Dict.toList dict` — was the following:

```elm
dict |> Dict.foldr (\\k -> (::) << Tuple.pair k) []
--> Dict.toList dict
```

That's the level of polish that was put into this rule over the years, and I couldn't be more proud of it, and thankful to [@lue](https://github.com/lue-bird) for his great work.

I was originally thinking of ending the article with the list of new simplifications, but the rendering on this website didn't make it justice.
I highly recommend you go take a look at the [changelog](https://github.com/jfmengels/elm-review-simplify/blob/main/CHANGELOG.md#2111---2025-12-30),
where you'll see around 80 new simplifications, on top of what I've already mentioned.

I hope you enjoy all of these changes, I sure enjoyed working on them!
And you can bet I'm going to enjoy every single one of the new fixes I will now encounter!  

[`NoUnused.Exports`]: https://package.elm-lang.org/packages/jfmengels/elm-review-unused/1.2.5/NoUnused-Exports
[`NoUnused.Variables`]: https://package.elm-lang.org/packages/jfmengels/elm-review-unused/1.2.5/NoUnused-Variables
[`NoUnused.Patterns`]: https://package.elm-lang.org/packages/jfmengels/elm-review-unused/1.2.5/NoUnused-Patterns
[`NoUnused.Parameters`]: https://package.elm-lang.org/packages/jfmengels/elm-review-unused/1.2.5/NoUnused-Parameters
[`NoUnused.Dependencies`]: https://package.elm-lang.org/packages/jfmengels/elm-review-unused/1.2.5/NoUnused-Dependencies
[`NoUnused.CustomTypeConstructors`]: https://package.elm-lang.org/packages/jfmengels/elm-review-unused/1.2.5/NoUnused-CustomTypeConstructors
[`NoDeprecated`]: https://package.elm-lang.org/packages/jfmengels/elm-review-common/1.3.5/NoDeprecated
[`NoPrematureLetComputation`]: https://package.elm-lang.org/packages/jfmengels/elm-review-common/1.3.5/NoPrematureLetComputation
[`Simplify`]: https://package.elm-lang.org/packages/jfmengels/elm-review-simplify/2.1.11/Simplify