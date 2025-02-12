---
title: Package releases (August 2021)
slug: package-releases-august-2021
published: "2021-08-15"
---

I recently spent some time going through the existing issues and features ideas I had for some of my `elm-review` packages.
It's a lot of individual changes, but there are enough of them for deserving a whole article.

## [elm-review-common](https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/)

### NoPrematureLetBody

I introduced this rule [last week](https://jfmengels.net/easier-automatic-fixes/).

In this release, the rule made sure not to move a let declaration to inside a function (let function or lambda), because the function could end up being called multiple times, causing the value to be computed multiple times compared to before the change.

While that is still true, the rule now moves the let declaration inside some functions, when we know for sure the function is only going to be called at most once, such as lambdas passed to `Maybe.map`.

```elm
someFunction maybeItem n =
    let
        -- Will be moved from here...
        value =
            expensiveComputation n
    in
    Maybe.map
        (\item ->
            if condition item then
                -- ... to here
                value + item.value

            else
                0
        )
        maybeItem
```

This way, though only for a select number of functions (from `elm/core` only for now), there won't be a difference in treatment whether you're branching using a `case` expression or using the core functions to work with those.

The rule is sturdy or smart enough through some mechanisms to not put variables in these functions even when it's defined in something like `List.map`, so no need to worry too much! 

## [elm-review-unused](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/)

### NoUnused.Parameters

There were a few false negatives in this rule, that unfortunately demanded a big rewrite of the rule. But it's back stronger than ever! The false negatives (errors not reported when they should have been) in question were for let functions, when they defined arguments with the same name.

```elm
a =
    let
        fn1 value = value + 1
        fn2 value = 1 -- not using value here
   in
   ...
```

---

The rule now doesn't report unused "named patterns" anymore.

```elm
type Thing = Thing Value
thing (Thing _) = ...
```

The reasoning is that you could want to keep the value there as a compiler reminder, in case you want to add more variants to your type later. We still report `unused` in the following example

```elm
type Thing = Thing Value
thing (Thing unused) = ...
```

at which point it will be up to you to notice that the whole parameter is unused and could potentially be removed.

---

The rule now also reports parameters only used in recursion.

```elm
last list unused =
    case list of
        [] ->
            Nothing

        [ a ] ->
            Just a

        _ :: rest ->
            last rest unused
```

![](/images/package-releases-august-2021/unused.png)

### NoUnused.Variables

Any let declaration that doesn't introduce any variables will now be removed.

```elm
a =
    let
        (Thing _) = ...
   in
   ...
```

Previously, this was not the case for "named patterns". `NoUnused.Patterns` took care of simplifying this to a shape that `NoUnused.Variables` was comfortable removing, so it's not anything new. But now this change will be done in fewer fix steps (so a bit faster) and if you don't have `NoUnused.Patterns` enabled.

### NoUnused.Exports

The rule now tries to remove the `@docs` entry in the module's documentation along with the unused export.

```elm
module Email exposing (Email, email)

{-| An email address.

@docs Email, email

-}

type Email
    = Email String
```

![](/images/package-releases-august-2021/exported-docs.png)

Since the rule doesn't report any issues for exposed modules of packages, this will not happen too often. This will in practice be more useful for developers who like to add nice documentation for their internal modules, both in applications and packages, and this change will prevent the code and documentation getting out of date.


## [elm-review-simplify](https://package.elm-lang.org/packages/jfmengels/elm-review-simplify/latest/)

`Simplify` is a never-ending rule. There is still [so much more to add](https://github.com/jfmengels/elm-review-simplify/issues/2), and help is welcome (just like with any of the rules and packages I maintain).

In this release I added some mechanisms to simplify comparison expressions. Previously, `constant == constant` would be simplified to `True`, and we were being somewhat smart in the sense that things would be caught even with some obfuscations like `SomeModule.constant == ( ( ( constant ) ) )` (if `constant` here does come from `SomeModule`).

But things like `1 == 2`, which is obviously `False`, was not being simplified. Well, now it is.

```elm
1 == 2 --> False
1 == 2 - 1 --> True
[ 1 ] == [ 1, 1 ] --> False
[ 1, 2 ] == [ 1, 1 ] --> False
{ a | b = 1 } == { a | b = 2 } --> False
-- and so much more...
```

and these are all true even if you try to nest them, so `[ 1 ] == [ 2 - 1 ]` would be considered as `True`, and so on. The rule tries to compute numbers as you may have been able to tell, but doesn't try to emulate or compute things like function calls for real to see if things are equal. That would in practice be very expensive.

---

Additionally, some more minor simplifications were added, such as `not (not x)` is being simplified to `x` (regardless of whether you used `|>`, `<|` or simple functions calls, all handled). The same thing is true for `negate`, `List.reverse` and `String.reverse`.

This is obviously on top of all the simplifications we already have, [listed here](https://package.elm-lang.org/packages/jfmengels/elm-review-simplify/latest/Simplify#simplifications).


## [elm-syntax](https://package.elm-lang.org/packages/stil4m/elm-syntax/latest/)

I now help maintain `elm-syntax`, the library that contains the AST that `elm-review` uses. I spent some time cleaning up the project, and came across some optimizations and some bugs, described in [the changelog](https://github.com/stil4m/elm-syntax/blob/master/CHANGELOG.md#version-727).


## Afterword

I hope you like all these changes. I'm not sure how much of an impact they will have, and how many new issues or simplifications they will help find. It's unlikely that you will have whole swaths of new issues (if you were previously up-to-date).

If each of my changes helps someone at some point, I'll be happy already. The idea is more that you have that you will have a "safety net" that you can learn to trust.

For instance, in code reviews, I barely wonder whether I forgot to use a value or not, because I know that the tool will let me know.

Similarly, if I write code that will be obviously simplifiable, which I like to do in an [incremental steps](https://elm-radio.com/episode/incremental-steps) approach, I know `Simplify` will be there to let me know I should remove the dumb code or go one step further to remove the hardcoded code.

And I hope that you'll get that same feeling of "safety" that I do.