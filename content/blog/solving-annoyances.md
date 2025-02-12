---
title: Solving annoyances
slug: solving-annoyances
published: "2022-08-25"
---

I just cut [`v2.9.0`](https://github.com/jfmengels/elm-review/blob/master/CHANGELOG.md#290---2022-08-23) of the [`jfmengels/elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/) Elm package,
a pretty big release with a lot of features, which solve a few annoyances for rule authors! Let's get into it!

## Module documentation visitors

This versions adds visitors (the functions that allow you to efficiently collect data from the project files) to access an Elm module's documentation.

```elm
module Some.Module exposing (something)

{-| Hi, I'm the module documentation!

This module does great things!
-}

import Some.OtherModule

-- ...
```

`elm-review` uses [`elm-syntax`](https://package.elm-lang.org/packages/stil4m/elm-syntax/latest/) to parse the Elm files.
Unfortunately, the way it is currently designed makes it not possible to easily access a module's documentation. In contrast to
the documentation of a function or type which is attached to the element, the module documentation is considered as a simple comment. 

Therefore, to get it, as a rule author you need to go through the list of comments and find the first one that starts with `{-|`.
If you weren't careful enough, you could run into false positives because the first comment that starts `{-|` could
technically be the documentation of a port (when the module does not have documentation) because ports also don't have
their documentation attached in the Abstract Syntax Tree (AST).

So, in this version, `elm-review` adds [`Rule.withModuleDocumentationVisitor`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withModuleDocumentationVisitor),
which allows you to visit the module documentation, without going through the trouble of sifting through the comments.

If you prefer accessing the module documentation through the `ContextCreator` (a way to initialize the context for the
data collection), there is now also [`Rule.withModuleDocumentation`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withModuleDocumentation).

In the 4 rules I had to implement this "find the module docs" logic, none of them were careful enough about the ports issue,
meaning that there was the possibility of false positives or negatives. They were thankfully never encountered
(or reported at least). A new version of each of these rules has been published as well (so upgrade all your
`elm-review` dependencies while you're at it) where this issue was fixed.

We will be working on fixing the root issue in `elm-syntax` by properly attaching module and port
documentation to the relevant parts of the AST, but that focus will be done later.


## Access to the full AST

As I mentioned before, `elm-review` uses the concept of "visitors" to collect data in the file that will be relevant to
the analysis. You add a visitor to look at the `module X exposing (a, b, c)` line, another one to look at the module's
documentation, another one to visit the different `import` statements, etc. In each of the visitors, you update the
`Context` (extremely similar to a `Model`, where a visitor would be an `update` function).

This is really nice in general, but it can be clunky sometimes, for instance if you wanted to know the list of exposed
elements in a module. To do that, you need to look at the module definition by adding a visitor to it.

```elm
module A exposing (A, b, c)
```

Ok, we see that `A`, `b` and `c` are exposed. Job done. What's clunky about this? Well, what if we had this code?

```elm
module A exposing (A(..), b, c)

type A
    = Constructor1
    | Constructor2
```

Well, this exposes `b` and `c`, as well as `A` and `A`'s constructors `Constructor1` and `Constructor2`. The problem here is that
when you visit the module's definition, you only have access to 2 pieces of information: the module's definition, and
the context in which you stored all the data that you've accumulated before.

The problem here is that the data about `A`'s constructors is not available in the module's definition. And since visitors
go through the AST in a specific order, you can't possibly have collected the data about this type yet.
This gets slightly worse if you have a module like `module A exposing (..)`, because you have even less data in the
module definition.

The way around this has been the following: Look at the module definition, if it's exposing everything, set a value in
the `Context` that says that the module is exposing everything. If it's exposing a list of specific things, collect that
list and store them in the context. Then visit the declarations, and depending on what you saw in the module definition,
add the declaration (and its potential constructors) to the list of exposed things.

The clunky part is needing intermediary data that will only be used to determine how to collect something else. In some cases,
you actually have to set up dummy data before you could fill it with what you had found through visitors. I have had to
do this kind of work so many times in several rules, and it never felt good.

So... one way to fix this is by giving you access to all the data you need beforehand. More specifically, when you
initialize your `Context`. That way, you can easily access the data you need without going through visitors, and combine
data from multiple parts of the file in an easy way, and *then* use visitors when it's more practical (for declarations and expressions, mostly).

That's why there is now [`Rule.withFullAst`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withFullAst)
which gives access to the raw `elm-syntax` AST, where you can directly get the module definition, the imports, the declarations, the comments, etc.

I was initially worried that people would then traverse parts of the AST multiple times (which using visitors prevents)
which would lead to a performance decrease. While this is still a potential problem, I think that in practice this will
help reduce the complexity of a rule, and potentially lead to less work.

One aspect that I would really like to explore and that this kind of features potentially unlocks, is being able to
change how the modules get visited based on some preliminary checks. For instance, if a rule wants to find usages of `Html.button`, and by looking at the
imports it sees no imports to `Html`, then it can skip adding an expression visitor, or maybe even skip looking at the
rest of the file. It's still very rough in my head, but this sounds exciting for performance, and I'd love help with designing this. 



## Testing the module name lookup table

I was recently adding a new feature to [`elm-review-simplify`](https://package.elm-lang.org/packages/jfmengels/elm-review-simplify/latest/)
and... what? I didn't mention this to you yet? Ok, slight digression.

Since `v2.0.17`, the `elm-review-simplify` package now has the ability to infer values from if conditions, which it will
use to simplify boolean expressions and even to remove some `if` branches. For instance:

```elm
if a && b then
  if a then -- we know this must be true
    1
  else -- so we can remove this else
    2
else
  3
```
becomes
```elm
if a && b then
  1
else
  3
```

It now does a bunch of these simplifications, and more improvements to this will gradually be added. You can read more
about it on the package's [changelog](https://github.com/jfmengels/elm-review-simplify/blob/main/CHANGELOG.md#2017---2022-08-14).

---

So... back to the `elm-review` package. So for `elm-review-simplify`, I started having a very complex function in its implementation,
and decided to unit test it. This function takes a `ModuleNameLookupTable` as an argument, which is a construct to know
what the "real" module name in a reference.

```elm
import Html exposing (..)
import Html.Attributes as Attr

view model =
    div
      [ Attr.class "some-class"
      ]
      -- ...
```

In the AST, the module name for the reference `div` is `[]`, but where it really comes from is `[ "Html" ]`.
For `Attr.class`, the module name is `[ "Attr" ]`, but the real module name is `[ "Html", "Attributes" ]`.

The `ModuleNameLookupTable` is a helper to let us know the real module name of a reference, which is useful for instance
to accurately target a function.

Unfortunately, this lookup table is not something that you can create manually. It is provided by `elm-review`'s framework.
And this means that this function was not available in unit tests.

But now we have [`Review.ModuleNameLookupTable.createForTests`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-ModuleNameLookupTable#createForTests)!

Suffice to say that the name should indicate that it should not be used in rules, and only for tests.

And now I have a nice test suite for that function 😊



## Direct dependencies vs all dependencies

`elm-review` has a visitor to let you access a project's dependencies, called [`withDependenciesProjectVisitor`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withDependenciesProjectVisitor)
(and for module rules, there is `withDependenciesModuleVisitor`).

A problem that was reported recently highlighted a problem with the `ModuleNameLookupTable` where it did not correctly
find a module name, because there was a module in the user's indirect dependencies that had the same name as one in the user's project.

I solved the issue by ignoring the indirect dependencies in the buggy part. But that made me think that the indirect
dependencies are rarely useful to look at. In practice, we tend to only care for the direct dependencies, because their
modules are accessible from the source code, while the indirect dependencies' aren't.

`v2.9.0` introduces [`Rule.withDirectDependenciesModuleVisitor`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withDirectDependenciesModuleVisitor)
(for rules that only look at modules) and [`Rule.withDirectDependenciesProjectVisitor`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withDirectDependenciesProjectVisitor)
(for rules that look at the whole project). These are doing the same thing as `Rule.withDependenciesModuleVisitor` and
`Rule.withDependenciesProjectVisitor`, but instead of giving you all the dependencies it only gives you the direct
dependencies (`dependencies.direct` and `test-dependencies.direct` in `elm.json`).


## NoUnused.Exports and NoUnused.Modules

I solved another annoyance in [`jfmengels/elm-review-unused`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/) `v1.1.23`.

A common issue when running `elm-review --fix` (or `--fix-all`) was when you had both the `NoUnused.Exports` and
`NoUnused.Modules` rules enabled and encountered an unused module.

While in fix mode, [`NoUnused.Exports`] would remove every export one at a time, which would likely be followed by
[`NoUnused.Variables`] removing the previously exported element. This would go on until the module is as empty as it can
be, at which point you would finally be able to see `NoUnused.Modules`'s error indicating that the module is unused.

Whether you want to remove the module or use it somewhere in response to this message, this is a lot of unnecessary work
for you and/or the tool, making `--fix-all` painfully long.

This version merges the `NoUnused.Modules` into the `NoUnused.Exports` rule. By having the `NoUnused.Exports` do the work of both rules, and not reporting any unused exports when the entire module
is unused, this situation should not happen anymore, or at least not as exacerbated.

`NoUnused.Modules` is therefore now deprecated and should not be used anymore. It is removed from the different starter
configurations.


## Afterword

I hope you didn't encounter these annoyances too often, but if you did, then I hope that these changes will solve them for you.

As always, if you want to help out by contributing to the projects, please get in touch! And if you want to help out
financially, I have a [GitHub sponsors](https://github.com/sponsors/jfmengels) page for you and/or your company to check out. 


[`NoUnused.Modules`]: (https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Modules)
[`NoUnused.Exports`]: (https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports)
[`NoUnused.Variables`]: (https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Variables)