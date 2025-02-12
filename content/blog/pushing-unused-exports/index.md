---
title: Pushing unused exports detection one step further
slug: pushing-unused-exports
published: "2023-07-28"
---

I just released a new version of [`jfmengels/elm-review-unused`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/) which is an [`elm-review`](https://elm-review.com) (a static analysis tool for the Elm language) package to report and remove unused code.

The new addition is a setting for the [`NoUnused.Exports`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports) rule.
As a reminder, the base rule reports an error when a module exposes a function or type that is never used in other modules, and then removes that for you automatically.

When that declaration stops being exposed, then it may be detected as unused inside of its own module and removed altogether, hopefully starting a snowball effect and deleting a large amount of unused code. I talk about how it works so well in [this other article](/safe-dead-code-removal/).

The new setting is an opt-in way of detecting exposed declarations that are used, but **only** in non-production code such as tests or a styleguide.

## Used but unused code

Let's say we have a module `A`:

```elm
module A exposing (add, divide)

add a b = a + b
divide a b = a / b
```

and a module `B`:

```elm
module B exposing (something)

import A

something = A.add 1 2
```

In this example, we notice that `divide` is unused, so therefore we want to remove it so we don't need to maintain it anymore. And that's what the rule does today.

Now let's say that we also have a test file in our codebase, like the following:

```elm
module ATest exposing (tests)

import A exposing (divide)
import Expect
import Test exposing (Test, test)

tests : Test
tests =
    test "the divide function should correctly divide two numbers" <|
        \() ->
            divide 10 2
              |> Expect.equal 5
```

In this situation, `divide` does not get reported because it is used in a test dedicated to it. But this is not production code. We are not using it to provide value to our users, so... what's the point of keeping this code?

Well, there isn't really, so we'd like to remove it. And that's what the rule is now able to do.

## Using the new setting

I wanted to avoid a breaking change for the package, so `NoUnused.Exports.rule` can still be used and will have the same behavior as before this release.

To enable this, you will want to use the following configuration:

```elm
NoUnused.Exports.defaults
    |> NoUnused.Exports.reportUnusedProductionExports
        { isProductionFile = \{ moduleName, filePath, isInSourceDirectories } -> isInSourceDirectories
        , exceptionsAre = [ annotatedBy "@test-helper", suffixedBy "_FOR_TESTS" ]
        }
	|> NoUnused.Exports.toRule
```

In the next major version (whenever there is a good reason for a breaking change), I will remove `rule` and rename `toRule` to `rule`, so that we have something similar to what is done for other configurable rules.

I describe the configuration better in the [documentation](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports), but here is the rough idea: we need to know which files to consider as production (and non-production) files, and we need to have a way to tag exceptions to remove false positives.

### What is a production file?

Production files by default are the files in your project's `source-directories` (or `src/` for packages), and non-production files are the rest, which usually means the `tests/` folder. We could have stopped there and that would have been reasonable but incomplete.

At work, we have a component library, full of reusable UI elements that we use all over the codebase. We even have a styleguide for it, which is an internal website we use to show all the different variants of our elements. That styleguide is generated automatically by finding all the `Example.elm` files. For instance, if there is a `src/Ui/Button/Example.elm` module next to a `src/Ui/Button/Button.elm` , then we will automatically integrate it in the styleguide.

Even though these files are in a source directory, we don't want to consider these `Example` files as production code. If we have UI elements that are only used in examples, then similarly to tests, we would like to remove them.

In practice this can be a bit more complicated than for tests, as there may need to be a conversation with your designers in which you should tell them that some UI elements are never used. Maybe that's okay and they should be removed. Or maybe that should be a wake-up call because they should have been used in some pages but clearly they aren't.

### Exceptions

Unfortunately, this setting introduces false positives. For instance, we may have a few helper functions that are there to **enable** tests, without which it is technically not possible (or pretty complicated) to write a specific test. These are only going to be used in tests, but we'd like to keep these.

A large part of the design for the rule was trying to find ways to annotate exceptions in the least conspicuous way (no `// disable-linter`).
My solution was to give you multiple options through suffixes/prefixes, and documentation annotation. I think it's best
to leave it up to you to figure out what works best for your project.

## Discoveries


I have started applying this setting at work, and so far the discoveries have been multiple.

### Pulling the thread on unused code

First, I discovered a bunch of functions that were tested but simply unused in production code. Those functions I could remove without any problem.
This was unsurprising as that was the primary intent of the rule.

Here's a tip though: If you find some errors, try to pull on the reported errors a bit.

Let's say we have a function like this:

```elm
withColor : Color -> Thing -> Thing
withColor color (Thing thing) =
  Thing { thing | color = Just color }
```

Finding that you can delete this function is nice. But I notice a few things: the function modifies the `color` field, and that field is a `Maybe Color`.

After removing this function, you might notice that this `color` field is never used and that you therefore can remove it. Nice win!
(Yes, detecting unused record fields is on my todo list. In the meantime, you'll need to look for these yourself...)

If that's not the case, you may look at the possible values. This field is a `Maybe Color`, which is either `Just` a color or `Nothing`.
Without this `withColor` function, you might notice that the field is always `Nothing` (initialized once and then never re-assigned for instance).
In that case, you can remove it as well and simplify the places that this field was used (to do whatever it was doing in the `Nothing` case).

Again, detecting "constant" values for record fields would be a very interesting addition (or at least exploration) for an `elm-review` rule.


## Bad tests

My second discovery was bad tests.

For instance, I noticed a bunch of tests creating data using helper functions (not used in production code), when the public API used in production could have been used just as well. That was a dissonance between what we do in production code and what we do in tests, which can become problematic.

Similarly, I saw helper functions (not used in production code) to extract data from types and make assertions on those. While that can be interesting to test edge cases or performance-critical properties, there were a number of tests where using the public API would have been able to do the same assertions. That is preferable because you'll once again have fewer differences between production code and tests.

These tests may have been done incorrectly to start (I didn't go into the Git history yet), but code changes a lot and maybe change was the problem. Maybe when the tests were conceived, all these helper functions were used in production code, and it made sense to write tests for them. And then things changed and that wasn't so true anymore.

Even though this was not the point of the rule, I'm glad I was able to catch this now and improve the tests.

## Afterword

I hope you like this change to the rule and the changes it will cause on your codebase.

Please look at the [documentation](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports) of the rule to try it out. You can also try a pre-configured version of it by running the following command:

```bash
elm-review --template jfmengels/elm-review-unused/example-ignore-tests --rules NoUnused.Exports
```

Happy code deletion!