---
title: Announcing elm-review v2
date: '2020-04-30T00:00:00.000Z'
---

Today I am very excited to release `elm-review` 2.0.0 and to share its new features!

tl;dr: Here is the list of the features:

#### New review capabilities!

- Full project review!
- Reporting errors for `elm.json`
- Reading the dependencies' `docs.json` file
- Visiting the README.md file
- Visiting the comments and documentations

#### Easier to use!

- Configuring exceptions
- Much faster, and with a watch mode
- A `fix-all` flag
- Better default folder structure
- Tests included by default
- More rules to start with

## Sorry but... what is elm-review?

If you missed the [initial announcement](/announcing-elm-review/) or if your memory is unclear, let me explain.

`elm-review` is a static code analysis tool for Elm, which looks at your Elm project, and reports patterns that you configured it to find using "rules".

It is highly customizable because you can write your own rules. Since these are written in Elm, you don't need to know a different language to do so, and you can even publish them as Elm packages!

To some, `elm-review` looks like a linter. Which isn't necessarily wrong, since it enables you to enable rules that help improve the quality of your code. If you dive a bit further, you will find out that it can enforce coding conventions for your team, and create new guarantees that the Elm compiler can not give you.

TODO rephrase
Unfortunately, these guarantees were often partial guarantees as soon as a problem spawns several modules. But that was the case until we got...

## Full project review!

In `elm-review` version 1, `Elm Analyse`, `ESLint` and a lot of similar tools for other languages, the analysis is scoped to a single file.

This means that when a rule has finished looking at module A and starts looking at module B, it forgets everything about module A. That means we can't answer a lot of questions that we would like the answer to, such as:

- Which module does function `xyz` come from? If a module is imported using `import A exposing (..)`, then we potentially lose the ability to tell. We have the same problem with types when encountering `import A exposing (B(..))`.
- What is the type of an imported function?
- Is this element ever used in the project?

This version introduces _project rules_, in addition to what I now call _module rules_ that we just described. These rules go through all the modules and can use information collected from a different module to infer or report things, solving the problems mentioned above.

In short, this feature makes rules much more accurate, and allow for almost any of them to be _complete_. No more "best effort" due to the limitations of looking at a single module.

Example use-cases:

- [Report custom type constructors that aren't used anywhere in the project](https://package.elm-lang.org/packages/jfmengels/review-unused/latest/NoUnused-CustomTypeConstructors)
- [Report functions/types that are exposed but are never used in the project](https://package.elm-lang.org/packages/jfmengels/review-unused/latest/NoUnused-Exports)
- [Report unused modules](https://package.elm-lang.org/packages/jfmengels/review-unused/latest/NoUnused-Modules)
- Report unused fields in records
- Report when `Html.lazy` is used incorrectly
- TODO find other rules that are not only about unused things...

## Reporting errors for elm.json

In version 1, reading the contents of `elm.json` was possible, but it wasn't possible to report errors for it.

## Reading the dependencies' docs.json file

The `docs.json` file for the dependencies contain all the public information about your direct and indirect dependencies. Reading these can tell you which dependency a module comes from, along what types and functions they contain.
This gives you a lot of information about your direct and indirect dependencies, for instance what modules they contain and which functions and types are defined in there.

With this information, rules can be much more accurate. For instance, knowing what is added to the scope when encountering `import Xyz exposing (..)` becomes possible.

Added to the new information you get from the previous points, you now have sufficient knowledge to replicate the compiler's type inference logic!

Example use-cases:

- Report unused imports of the form `exposing (..)` or `exposing(..)` (coming soon in [`jfmengels/review-unused`](https://package.elm-lang.org/packages/jfmengels/review-unused/latest/NoUnused-Variables))
- [Report unused dependencies](https://package.elm-lang.org/packages/jfmengels/review-unused/latest/NoUnused-Dependencies)
- [Report dependencies with unknown or incompatible licenses](https://github.com/jfmengels/elm-review/blob/master/tests/NoInvalidLicense.elm#L21)

## Visiting the README.md file

The README is an integral part of the project especially for packages. For package authors and their users, it is important that everything in there is correct.

This version introduces a visitor for the README, which allows you to collect data from it and to report errors for it, that can be automatically fixed.

Example use-cases:

- [Make sure the links in your `README.md` point to the right version](https://package.elm-lang.org/packages/jfmengels/review-documentation/1.0.0/Documentation-ReadmeLinksPointToCurrentVersion)
- Make sure the links in your `README.md` point to existing modules
- Report invalid or badly formatted Markdown content

## Visiting the comments and documentation

You can also look at the contents of the comments or documentation of a function or module.

Honestly this was just me forgetting to add a visitor for it, it would have been an easy addition to v1.

Example use-cases (most of these are on my todo list for [`jfmengels/review-documentation`](https://package.elm-lang.org/packages/jfmengels/review-documentation/latest/)):

- Making sure that the `@docs` in the module documentation are always correct and up to date
- Report links to non-existing or non-exposed modules (or even to invalid functions/section ids) would be possible, and on my personal todo list
- Noticing duplicate Markdown sections
- Report the usage of words like `TODO`

## Much faster, and with a watch mode

Version 1 focused on usability, and on validating that it was a good solution to the problems it tried to solve. Therefore, performance concerns were ignored.

With version 2, performance was a focus, and the results are really good. Files are now cached, so the initial run is around as fast as for version 1, but subsequent changes are much faster. Probably around 6 to 10 times faster, but I haven't run any benchmarks. And I am sure we can do much better for future versions!

There is also a watch mode where, once started, the changes feel instantaneous.

The work done here should help pave the way to having editor support.

## Configuring exceptions

Version 1 had no way of allowing exceptions TODO

## fix-all flag

Version 1 had a `fix` flag, where it would propose automatic fixes for some of the problems that it knew how to fix, and you could accept or refuse them.

For some, it was very annoying to go through all the fixes as this could be long and tedious when you had a lot of errors.

So this version comes with a `--fix-all` where you get one big diff between the current source and the one where all fixes have been applied, and you can accept or refuse it.

I do not believe automatic fixes to always be perfect, and I know that there are some kinks in a few of the ones I wrote, so please be cautious when looking at the before/after diff and don't commit the changes blindingly.

## Better default folder structure

Some users encountered problems when trying to test write custom rules located in their `review/` folder, and had to move files around.
The "review application" that you get from running `elm-review init` is now structured in a way that makes it possible to test the rules out of the box.

`elm-review init` now adds the dependencies needed to write rules by default too.

## Tests included by default

The `tests/` directory is now included by default.

## Get started!

TODO

```
cd your-project/

# Using npm
npm install --save-dev elm-review
# Using Yarn
yarn add --dev elm-review

# Create a configuration
npx elm-review init

# Go add rules in `review/src/ReviewConfig.elm`
# The previous section lists quite a few

# Run it
npx elm-review
```

I recommend reading the [documentation](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/) before you go too far in, which will give you advice on how to best set up `elm-review` for your project and/or teammates.

## More rules to start with

Until now, the catalog of rules has been quite small, and I can understand that for many people this was a blocker for adoption.

Along with this release, I am publishing a lot more rules than the 3 I had previously written. You can find them by searching for `jfmengels/review-` in [the packages website](https://package.elm-lang.org), but among them are:

- [`jfmengels/review-debug`](https://package.elm-lang.org/packages/jfmengels/review-debug/latest/)
- [`jfmengels/review-unused`](https://package.elm-lang.org/packages/jfmengels/review-unused/latest/)
- [`jfmengels/review-simplification`](https://package.elm-lang.org/packages/jfmengels/review-simplification/latest/)
- [`jfmengels/review-common`](https://package.elm-lang.org/packages/jfmengels/review-common/latest/)

I know that a lot of people use `Elm Analyse`, and I imagine that some people were hoping find the rules it offers. To help with that, I published a few packages containing most of them. The ones I didn't include are ones that are automatically handled by `elm-format` or ones I disagree with.

As always, I suggest carefully selecting the rules you wish to enable, but here is how you could copy over your `Elm Analyse` configuration:

Run the following commands in your terminal

```bash
cd your-project/
elm-review init # Only if you were not using elm-review already
cd review/

elm install jfmengels/review-unused
elm install jfmengels/review-common
elm install jfmengels/review-debug
elm install jfmengels/review-simplification
```

and then add these rules to your configuration

```elm
import NoBooleanCaseOf
import NoDebug.Log
import NoDebug.TodoOrToString
import NoExposingEverything
import NoFullyAppliedPrefixOperator
import NoImportingEverything
import NoListLiteralsConcat
import NoMissingTypeAnnotation
import NoUnused.CustomTypeConstructors
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Modules
import NoUnused.Variables
import Review.Rule exposing (Rule)


config : List Rule
config =
    [ NoBooleanCaseOf.rule
    , NoDebug.Log.rule
    , NoDebug.TodoOrToString.rule
    , NoExposingEverything.rule
    , NoImportingEverything.rule []
    , NoListLiteralsConcat.rule
    , NoMissingTypeAnnotation.rule
    , NoFullyAppliedPrefixOperator.rule
    , NoUnused.CustomTypeConstructors.rule []
    , NoUnused.Dependencies.rule
    , NoUnused.Exports.rule
    , NoUnused.Modules.rule
    , NoUnused.Variables.rule
    ]
```

That should get your started, but don't forget there are plenty of other rules out there!

## How does this compare to Elm Analyse?

`Elm Analyse` is at the moment the de facto static code analysis tool for Elm. I firmly believe that `elm-review` version 1, (although the bad performance was a big nuisance).

Similar performance

One thing that `elm-review` is jealous of, is its editor support. But I expect that `elm-review` will have some of that in a not so distant future!

TODO

---

## Towards awesome rules

I think that `elm-review` lowers the barrier to entry to the realm of static code analysis, thanks to a great API, and by allowing anyone to use a rule without the maintainer of the tool's consent and effort. I believe that this will, in turn, make people create new useful and awesome rules for everyone to use. Here is a [list of rule ideas](https://github.com/jfmengels/elm-lint/projects/4) that I have. Maybe these will inspire you with great rule ideas.

## Future steps

First of all, I would like to make sure that `elm-review` is working well and as expected, and that people are finding uses for it. I want to make sure that writing rules and testing them all have a great experience.

I also think that `elm-review`'s configuration API will need to change to accommodate exceptions, different rules for different folders (src/ vs tests/ for instance), but this will depend on the pain points that users will give as feedback.

Some of the things I then want to work on include:

- Performance: It has not been too much in my radar. I have done some small performance optimizations, but the biggest improvements, like caching file contents have not been made yet. The goal is mostly to have `elm-review` working on very big projects, in a reasonable time.
- Give more information to rules: I want to be able to load the Elm interface files and pass them to the rules. This way, a rule could be able to tell which package an imported module comes from, tell the type of any function and therefore of any expression.
- Add project-wide rules. At the moment, like a lot of tools, rules only look at a single file at a time, and forget what they have seen when they start analyzing a different file. The idea would be to add the ability for some rules to analyze all the files, and report problems depending on that. One of the goals is for instance to be able to report functions exposed by a module that are used nowhere, like [`elm-xref`](https://github.com/zwilias/elm-xref) does. I am very concerned about the performance implications of this, and have mostly therefore left it for later, but doing this would allow for much more advanced and helpful rules: much better dead code elimination detection, detecting dead internal links in documentation, detecting unused dependencies...

## Feedback and help appreciated

I hope you will try `elm-review` and enjoy it. I spent a lot of time polishing it to give you a great experience using it and writing rules, but there is room for a lot of improvement.

I would love to hear from you if you have constructive criticism, want to help out, want to share what you are using it for, or just want to share that you enjoy it (yes, that helps a lot), let me know!

There is an `#elm-review` channel on the Elm Slack where you can do that or ask for help, and you can talk to me privately at @jfmengels over there.
