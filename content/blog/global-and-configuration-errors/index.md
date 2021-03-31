---
title: Global and configuration errors
date: '2021-03-13T14:00:00.000Z'
---

Today I'm releasing version `2.4.0` of the `jfmengels/elm-review`. It contains some missing features that could be considered core to `elm-review`, and that will be useful to people who will write review rules. In particular, the accent has been put on reporting errors.

- [Global errors](#global-errors)
- [Configuration errors](#configuration-errors)
- [Test dependencies](#test-dependencies)

# Global errors

In `elm-review`, all errors are tied to a location in the project, more specifically to a file (an Elm module, `elm.json` or the `README`) and a position in the file (where you'd see the squiggly lines). Pointing to a specific location in a project is really useful for users to quickly go and fix the location.

TODO Image example

Unfortunately it does not always make sense to point to a location in the code. For instance, what if a rule is expecting a module or a function to exist somewhere in the project (a `main` function for instance, or something that the user provides as part of the configuration) and that can't be found? Well you can't point the user to the `main` saying that it doesn't exist. There's no specific location to point to.

In [Safe unsafe operations in Elm](/safe-unsafe-operations-in-elm#making-sure-the-target-function-exists) we created a rule that takes as part of its configuration the name and module name of a function, which we would handle differently. In that article, we mentioned the problem that if the function could not be found, we would create an error for the `elm.json` file, because that's the best we could do, though it was still kind of confusing.

To resolve this problem, `2.4.0` of the package adds ways to create [**global errors**](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#globalError), which are by definition not tied to a location in the project.

```elm
error : String -> Error scope
error moduleName =
    Rule.globalError
        { message = "Could not find module " ++ moduleName
        , details =
            [ "You mentioned the module " ++ moduleName ++ " in the configuration of this rule, but it could not be found."
            , "This likely means you misconfigured the rule or the configuration has become out of date with recent changes in your project."
            ]
        }
```


TODO Image example

Global errors are easy to create, but they are also less helpful to the users, so they should be used only when other errors are inappropriate. They don't allow for automatic fixes either.

Testing rules is also part of the experience of writing review rules, that's why there are [new functions](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test#expectGlobalErrors) to assert that the rule behaves as expected.

# Configuration errors

TODO

TODO Make node-elm-review point configuration errors to the review config file?

- How would we still make it clear that it's a configuration error?

TODO
Think about whether to allow global errors to mention they are configuration errors, in order to point to the configuration file.

- What does that imply for tests?
- Would other rules also be reported?

# Test dependencies

TODO

Quality of life improvement.

- test dependencies
- elm/core by default in there.
- script

# A quest for holism

> Incorporating the concept of holism, or the idea that the whole is more than merely the sum of its parts, in theory or practice:
>
> -- Definition of the word **holistic**

I took a week off from work recently to relax and do fun stuff. One of the things I like doing and did during that week was to work on `elm-review`.

This time, I set off to work on a small feature, instead of bigger tasks that I had been working on, to get more immediate gratification from my work and get a feel-good boost.

There is just one problem with that: small features are rare, and as a project grows, increasingly so.

When I intended to add global errors, which is a pain point I felt (rarely, but surely), I figured the task would be relatively easy and fast.

TODO

- node-elm-review report of global errors
- Add functions enabling this
- Add ways to assert global errors in tests and fail tests where unexpected global errors are reported, with [compiler-like failure messages](/great-failure-messages)
- TODO Mention global errors and configuration errors in the tooling-integration document
- Documentation
- Writing tests
- Writing/adapting rules using global errors
- Writing an announcement like this one

TODO Talk about creating a wholesome experience.

All of these tasks also seem straightforward after the fact, but an announcement like this skips over the several attempted designs or implementations that have an impact on the other tasks. For instance, in this case, I had started with a very different API for testing. Once I was done, I noticed it was wonky and completely changed it, which required big changes in the core implementation too.

I had a very similar experience with the work on introducing the `--template` flag which allows users to run `elm-review` with a configuration they found on GitHub, as I explain in the [announcement post](/2.3.0-just-try-it-out/).

How complex can it be to use a remote configuration? Instead of taking the

TODO template feature

- TODO new-package, system of `preview/` and `example/`
- Allowing --template in `elm-review init --template` (as detailed in [the announcement](/2.3.0-just-try-it-out#new-package) and the [maintenance document](https://github.com/jfmengels/elm-review-unused/blob/master/maintenance/MAINTENANCE.md))
- Nice error messages for anything that may go wrong
- Bypassing GitHub API rate limits through a flag.
- Re-using the feature to download the default configuration for getting an up-to-date review configuration.
- TODO

Part of the smaller tasks that remain are fixing bugs, because they are indeed pretty fast to fix. Because I put a lot of work into making the experience great, I kind of see my project as a nice spherical balloon. If there is a bug or a part of the experience that is sub-par, then it's like if there is a whole in the balloon. Fixing a bug often takes relatively little time, so every time I do that, the sphere becomes "whole" again, which makes me feel good.

If you are working on a project where the experience is not great, then it's like a random shape with a lot of holes. Fixing a bug or improving the experience in one part doesn't bring a lot of joy, because it doesn't feel like the overall shape has changed: it's still a random shape with a lot of holes.

I recommend trying to get a project as soon as possible to that nice spherical shape before making it expand further. The users will like it more, and you will feel better maintaining it.
