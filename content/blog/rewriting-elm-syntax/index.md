---
title: Rewriting elm-syntax and future plans
published: "2024-07-27"
---

I'm happy to announce new versions `7.3.3` and `7.3.4` of [`stil4m/elm-syntax`](https://package.elm-lang.org/packages/stil4m/elm-syntax/latest/), the parser for Elm code written in Elm that is used in `elm-review` and other great projects.

While the new `7.3.3` (and `7.3.4` released in the meantime) looks like a trivial patch version, it is an almost complete rewrite using Pratt parsers. The whole change was made without any API changes, hence the *maybe disappointing* patch version (but semver is working as intended, you can upgrade without needing to make any changes).

## Migration to Pratt parsers

Prior to `7.3.3`, the source code was parsed and then post-processed - to rebalance the tree around operator precedence and to attach documentation comments. This is now all done in a single pass using a Pratt parser, which you can read more in depth about in [Martin Janiczek's article](https://martin.janiczek.cz/2023/07/03/demystifying-pratt-parsers.html).

I started the work in June of last year and got stuck on some problems. [@janiczek](https://github.com/janiczek) helped out with this, and then [@jiegillet](https://github.com/jiegillet) came around and knocked it out of the park - completing the parser, looking for regressions across a lot of Elm code out there and improving performance.

Surprisingly, the performance was initially not as good as expected - I expected the removal of the post-process step to speed it up - but after some performance improvements we got it to be about 15% faster than before the rewrite, and that's what was released in `7.3.3`.

After that, [@lue-bird](https://github.com/lue-bird) joined the fray to crank out performance, and made `7.3.4` about **90% faster** compared to `7.3.3`! And he is improving performance still, but that will have to wait for future versions.

The final result is that the parser is now **more than twice as fast as in `7.3.2`** (+115%, or 2.15x times as fast). I plan to write about some of the optimizations we found, because I don't know that they're common knowledge.

This rewrite includes a few bug fixes where code that was incorrect Elm code (according to the Elm compiler) was successfully parsed, and vice-versa. Overall, we want to stick very close to what the Elm compiler does and does not consider valid code. Although sometimes the line is subtle between a syntax error and what is objectively an error, but of a different kind.

## What's next for elm-syntax?

v7 has had a long life, and over that time span, many ideas have come up to improve the AST - in breaking ways. I would like to combine them all in a new major version, whose codename is... v8. Plainly, but that's considering that we don't mess it up and have to release a v9 afterwards 😅

The reason I'm writing about this is because I would love help on this and get the design as right as possible. Releasing a major version can be disruptive for tools like `elm-review` (all plugins would need to be adapted and re-released) and I don't want that to happen too often (otherwise I would have released some changes years ago).
So I'd like to hear from you - ideally in [an issue](https://github.com/stil4m/elm-syntax/issues) - if you see any area of improvement. Even bike-shedding on names is fine by me, because we are renaming a number of AST nodes.

You can read find more in the [ongoing PR for v8](https://github.com/stil4m/elm-syntax/pull/188) and in [`breaking-change` issues/PRs](https://github.com/stil4m/elm-syntax/labels/breaking%20change), but here's a few of the main intentions for the new version.

### More information

We want to add positional information. v7 is a weird mix between an AST (Abstract Syntax Tree) and a CST (Concrete Syntax Tree).

An AST describes the structure of the code without positional information. For instance, the code `1 + 2` could be described with the following AST (not the one we use):

```elm
Operation
  (IntegerLiteral 1)
  "+"
  (IntegerLiteral 2)
```

While this is sufficient for a number of uses, for instance for compilers during the code generation phase or potentially `elm-codegen`, it's insufficient for other uses such as reporting errors (linters like `elm-review` or a compiler during the verification phase) where the location of AST nodes is needed in order to tell the user there is an error at *that specific location in the code*. For that, the AST ends up looking more like:

```elm
Node
  { start = { row = 1, column = 1 }, end = { row = 1, column = 6 } }
  (Operation
	  (Node
		  { start = { row = 1, column = 1 }, end = { row = 1, column = 2 } }
		  (IntegerLiteral 1)
	  )
	  "+"
	  (Node
		  { start = { row = 1, column = 5 }, end = { row = 1, column = 6 } }
		  (IntegerLiteral 2)
	  )
  )
```

Some information is available - or at least computable or inferable - while others is impossible to determine without looking at the original source code.

For instance, notice above that the `"+"` isn't wrapped in a `Node` and we don't know its exact location. This makes it impossible to know its location in this example. We would end up with the exact same AST if the code was `1+  2` or `1  +2`.

This kind of information can be necessary for some automatic fixes in `elm-review` rules, hence why I want more information to be present in the AST.

As far as I understood it, a CST would push the adding of positional information to the limit, meaning you could determine the position of even whitespace. But I don't see that as being useful in the context of Elm.

For instance, you could think that it could be interesting to a linting rule that forbids trailing whitespace at the end of a line. But we already have a tool for that: `elm-format`. In an ecosystem where `elm-format` is so present, I can't think of a situation where knowing about whitespace is important.

So what we will add in the next version is the position of every symbol such as operators, `->`, `:`, `in`, etc. But we will likely skip the ones that can be inferred. For instance, the `let` keyword is simply the first 3 characters of the range of the `LetExpression` AST node. Avoiding storing this is almost entirely out of a performance concern.

Similarly, there are other pieces of non-positional information that we want to add. For instance, is a string created using single or triple quotes? Currently, you can't tell that from the AST.

If you know of some information the AST does not provide and would like it to do, let us know!

### Making impossible ASTs impossible

We will get rid of a few AST node types that can't happen. For instance, the `Declaration.Destructuring` variant is not possible since Elm 0.19, and users of the library have had to handle this impossible case anyway. I know of a bunch of places where removing this would allow replacing `List.filterMap` by `List.map`.

Another example: The `Expression.Operator` node is used only in the pre-processing phase of the parser, and is removed (replaced) during the post-processing. But the node still needs to be handled as a possibility by users of the package. With the Pratt parser, we don't need the node during the pre-processing phase at all, hence why we will be removing it altogether.

We also want to prevent more impossible cases. For instance, it's not possible to have a `RecordUpdateExpression` `{ x | y = z }` without any field assignments, so we will use structures resembling non-empty lists.

For patterns, we are adding a new kind of pattern that can be used for destructuring patterns, such as function arguments and let declarations, compared to `case of` patterns. For instance, you can have a case pattern like `Just 1 -> ...`, but you can't have `someFn (Just 1) = ...`. Separating the two means you won't have to handle patterns that are in practice impossible to get.

I hope you get the gist. If you think of more improvements in this area, let us know.
### Renaming

The naming of the different nodes has been somewhat inconsistent. For instance, we have a `RecordExpr` but a `RecordUpdateExpression`, a `LetExpression` but an `IfBlock`, and more... It's time to make the naming nice and consistent.

We are also evaluating moving all the AST types into a single module, instead of having them in separate modules (`Elm.Syntax.Expression`, `Elm.Syntax.Declaration`, ...). While that could be nice, that impacts naming as there is some naming overlaps between the different ASTs.

Please come and bikeshed on this before it's too late.

### Dropping features

We will also be dropping two functionalities that v7 supports.

One of them is [`Elm.Writer`](https://package.elm-lang.org/packages/stil4m/elm-syntax/7.3.3/Elm-Writer) which allows one to convert the AST to Elm code as a string. In practice the writer is not very good, and we have been recommending people to use [`the-sett/elm-syntax-dsl`](https://package.elm-lang.org/packages/the-sett/elm-syntax-dsl/latest/) for a long time, and [`elm-codegen`](https://package.elm-lang.org/packages/mdgriffith/elm-codegen/latest/) in some other situations.
Hence why I think removing it is fine. We can always bring it back in a minor version by copying it from `elm-syntax-dsl`.
(discussion thread: https://github.com/stil4m/elm-syntax/issues/198)

The other functionality is JSON (de)serializing of the AST. Apart from quick prototypes, it isn't used in current tooling as far as I know. `elm-review` used it at some point, but that got replaced by serializing it to bytes using [MartinSStewart/elm-serialize](https://package.elm-lang.org/packages/MartinSStewart/elm-serialize/latest/) which yields better performance for caching on disk.

I do plan on having some kind of documentation or example where people can copy an implementation if they need to, but I'm at this point thinking that it should not remain in the package.
(discussion thread: https://github.com/stil4m/elm-syntax/issues/197)


### Better error messages

Maybe not now, but it would be nice if we could get much friendlier (compiler-like) error messages, instead of the ones we have today which look like the following:

```elm
[{ problem = ExpectingSymbol "=", row = 3, col = 8 }]
```

This will likely not be a part of `v8` but it's worth starting to think about.

## Afterword

I hope you will enjoy using a faster `elm-syntax`, I'm sure I will (at least for a while).

I also hope the plans for `v8` are inspiring (or at least interesting to read about).

For now we aim to support v7, so if you find bugs in the new versions, we can still address them and release them as patch versions until the moment `v8` gets released.

All current and upcoming changes in `v8` are still up to debate. **This is the time** to come tell us about pain-points you have, and other suggestions you have to improve the public-facing API.

A big thank you to [@jiegillet](https://github.com/jiegillet),  [@lue-bird](https://github.com/lue-bird) and [@janiczek](https://github.com/janiczek) for their invaluable help. And to you who will help out with the `v8` effort in the future 😉

If you appreciate my work on the Elm ecosystem (`elm-review`, `elm-syntax` and more), please consider [sponsoring me](https://github.com/sponsors/jfmengels) and the [other folks looking for sponsorship](https://github.com/jfmengels/awesome-elm-sponsorship)
(Especially, talk your company into sponsoring, please DM me if you want to talk).