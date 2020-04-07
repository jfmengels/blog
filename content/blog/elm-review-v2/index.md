---
title: elm-review v2!
date: '2020-04-30T00:00:00.000Z'
---

Today I am very excited to release `elm-review` 2.0.0 and to share its new features!

tl;dr: Here is the list of the introduced features:

#### New review capabilities!

- Project rules!
- Reporting errors for `elm.json`
- Reading the dependencies' `docs.json` file
- Visiting the README.md file
- Visiting the comments and documentation
- Adding helpers

#### Easier to use!

- Much faster, and with a watch mode
- Configuring exceptions
- A `fix-all` flag
- Better default folder structure
- Tests included by default
- More rules to start with

## Sorry but... what is elm-review?

If you missed the [initial announcement](/announcing-elm-review/) or if your memory is unclear, let me explain.

`elm-review` is a static code analysis tool for Elm, which looks at your Elm project, and reports patterns that you configured it to find using "rules" in a friendly Elm compiler-like way.

It is highly customizable because you can write your own rules. Since these are written in Elm, you don't need to know a different language to do so, and you can even publish them as Elm packages!

I put a lot of effort into making a **very nice API** for you to use. even going through the lengths of discovering new Elm techniques (expect to see blog posts on the **phantom builder pattern** on this blog), and I am very happy with the result!

To some, `elm-review` looks like a linter. Which isn't necessarily wrong, since it enables you to enable rules that help improve the quality of your code. If you dive a bit further, you will find out that it can enforce coding conventions for your team, and create new guarantees that the Elm compiler can not give you.

For instance you can write rules that

- report when you [pass values outside of 0-255 to `Css.rgb255`](https://package.elm-lang.org/packages/folq/review-rgb-ranges/latest/)
- Give an error if any `Regex.fromString` calls have invalid regexes (for literal strings)

Unfortunately, as soon as a problem spawns multiple modules, you wouldn't be able to enforce those guarantees. But that was the case until we got...

## Project rules!

In `elm-review` version 1, `Elm Analyse`, `ESLint` and a lot of similar tools for other languages, the analysis is scoped to a single file.

This means that when a rule has finished looking at module A and starts looking at module B, it forgets everything about module A. That means we can't answer a lot of questions that we would like the answer to, such as:

- Which module does function `xyz` come from? If a module is imported using `import A exposing (..)`, then we potentially lose the ability to tell. We have the same problem with types when encountering `import A exposing (B(..))`.
- What is the type of an imported function?
- Is this element ever used in the project?

In addition to the **module rules** that we just described, `elm-review` now has **project rules**. These rules go through all the modules and can use information collected from a different module to infer or report things, solving the problems mentioned above.

In short, this feature makes rules much more accurate, and allow for almost any of them to be _complete_. No more "best effort" due to the limitations of looking at a single module.

This opens up a wide range of possibilities. A few example use-cases:

- [Report custom type constructors that aren't used anywhere in the project](https://package.elm-lang.org/packages/jfmengels/review-unused/latest/NoUnused-CustomTypeConstructors)
- [Report functions/types that are exposed but are never used in the project](https://package.elm-lang.org/packages/jfmengels/review-unused/latest/NoUnused-Exports)
- [Report unused modules](https://package.elm-lang.org/packages/jfmengels/review-unused/latest/NoUnused-Modules)
- Report unused fields in records
- If you generate a file containing the list of CSS classes next to your configuration, report the ones that are never used.
- Report when `Html.lazy` is used incorrectly
- Report when a variable that should contain all the possible variants of a custom type is missing a variant
- Report when a module uses another module's `update` function but not the `subscription` function

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

This version introduces a visitor for the README, which allows you to collect data from it and to report errors for it that can be automatically fixed.

Example use-cases:

- [Make sure the links in your `README.md` point to the right version](https://github.com/jfmengels/review-documentation/blob/master/src/Documentation/ReadmeLinksPointToCurrentVersion.elm)
- Make sure the links in your `README.md` point to existing modules
- Report invalid or badly formatted Markdown content

## Visiting the comments and documentation

With this version, you can also look at the contents of the comments or documentation of a function or module (To be honest, this was just me forgetting to add a visitor for it, it would have been an easy addition to v1).

Example use-cases (most of these are on my todo list for [`jfmengels/review-documentation`](https://package.elm-lang.org/packages/jfmengels/review-documentation/latest/)):

- Making sure that the `@docs` in the module documentation are always correct and up to date
- Report links to non-existing or non-exposed modules, or even to invalid functions/section ids
- Reporting duplicate Markdown sections
- Report the usage of words like `TODO`

## Adding helpers

Some tasks, like targeting a specific function, are harder than they should be. For instance, if you want to forbid `Foo.bar`, you'll need to handle multiple ways that the function can be called and imported, which is tedious and error-prone.

I started writing a helper named [`elm-review-scope`](https://github.com/jfmengels/elm-review-scope) that deals with this problem, and makes some tasks as easy as they should be.

## Much faster, and with a watch mode

Version 1 focused on usability and on validating that `elm-review` was a good solution to the problems it tried to solve. Therefore, I put few efforts into making a performant tool at the time.

With version 2, performance was a focus, and the results are really good. Parsed files are now cached, so the initial run is still a bit slow, but subsequent runs are faster by several times.

There is also a **watch mode** where the changes feel instantaneous.

And I am sure we can do much better for future versions! The work done here should help pave the way to having editor support.

## Configuring exceptions

When you enabled a rule in version 1, you wouldn't able to ignore any errors that it reported. You had to edit or fork the rule to ignore the cases you wanted to ignore.

The idea behind that was to avoid ignoring errors locally through a comment of some sort like what happens all over the place with `ESLint` ([which leads to all sorts of problems](https://github.com/jfmengels/elm-review/#is-there-a-way-to-ignore-an-error-or-disable-a-rule-only-in-some-locations)), and instead to have users [think on whether enabling a rule is a good idea](https://github.com/jfmengels/elm-review/#when-to-write-or-enable-a-rule) in the first place. And I still stand by these choices!

But there are places where it's reasonable to ignore review errors, namely for generated code and vendored code, and for introducing a rule gradually when there are too many errors. Sometimes, it also makes sense to have tests follow slightly different rules.

In these cases, you can [configure your rules](https://package.elm-lang.org/packages/jfmengels/elm-review/2.0.0/Review-Rule#configuring-exceptions) to not apply on a section on some directories or some files.

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

The `tests/` directory is now included by default. Since they are part of an Elm project, it makes sense to review them too.

## More rules to start with

Until now, the catalog of rules has been quite small, and I can understand that for many people this was a blocker for adoption.

Along with this release, I am publishing more rules than the 3 I had previously written. You can find them by searching for `jfmengels/review-` in [the packages website](https://package.elm-lang.org) (and in general by looking for `/review-` for other user's packages), but among them are:

- [`jfmengels/review-unused`](https://package.elm-lang.org/packages/jfmengels/review-unused/latest/)
- [`jfmengels/review-common`](https://package.elm-lang.org/packages/jfmengels/review-common/latest/)
- [`jfmengels/review-debug`](https://package.elm-lang.org/packages/jfmengels/review-debug/latest/)

I am also working on [a package to improve the quality of the documentation](https://github.com/jfmengels/review-documentation), which should help out package authors especially. And there are also some rules that I wrote, but am still unsure as to whether I want to maintain them personally, that you can copy over from [`jfmengels/review-simplification`](https://github.com/jfmengels/review-simplification).

## How does this compare to Elm Analyse?

##### Philosophy-wise

`Elm Analyse` is at the moment the de facto static code analysis tool for Elm, but it has [a different philosophy](https://stil4m.github.io/elm-analyse/#/contributing) from `elm-review`'s. `Elm Analyse` wants to improve the quality of the code by enabling rules that work for "everyone".

`elm-review` on the other hand aims to create guarantees tailored to your team and project, while enabling ways to improve the quality of the code too in a shareable manner.

If you think you have a rule that could be use to everyone, you can share it by publishing it in the Elm package registry.

##### Functionality-wise

Most checks (their naming for a rule) you can find in `Elm Analyse` are available in the packages I published or GitHub repos I have written. The remaining ones are ones that are outdated or that I disagree with, but these are reasonably easy to write using this package's API. (Exception for the checks for unused patterns and unused arguments which I plan to add). And anyone can publishing the missing ones if they care to.

From the tests I have run, I found `elm-review` to be faster. I am guessing that that is mostly because rules are built in a way that avoid duplicate work.

Here are the things that `Elm Analyse` has and `elm-review` hasn't:

- There is no web interface, but there is a similar CLI watch mode.
- `elm-review` doesn't show the graph of modules, but I don't really see the value that brings.
- `elm-review` doesn't show when dependencies can be updated. I see the value, but I don't think it is a good fit for the tool.
- There is no editor support for `elm-review`, but let me know if you want to help out with that!

As for the rest, I hope to have shown in this post and in the [original announcement](/announcing-elm-review/) what this tool can do that `Elm Analyse` can not.

## Get started!

If you already use `elm-review` in your projects, you can follow this [migration guide](https://github.com/jfmengels/elm-review/blob/master/documentation/Migration%20v1%20to%20v2.md). Otherwise, follow these instructions!

```bash
cd your-project/

# Using npm
npm install --save-dev elm-review
# Using Yarn
yarn add --dev elm-review

# Create a configuration
npx elm-review init

# Install dependencies that contain rules
cd review/
elm install jfmengels/review-unused
elm install jfmengels/review-common
elm install jfmengels/review-debug
```

and then add these rules to your configuration (FYI, these do not include the ones from [`jfmengels/review-documentation`](https://package.elm-lang.org/packages/jfmengels/review-documentation/latest/) nor [`jfmengels/review-debug`](https://github.com/jfmengels/review-simplification))

```elm
import NoDebug.Log
import NoDebug.TodoOrToString
import NoExposingEverything
import NoImportingEverything
import NoMissingTypeAnnotation
import NoUnused.CustomTypeConstructors
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Modules
import NoUnused.Variables
import Review.Rule exposing (Rule)


config : List Rule
config =
    [ NoDebug.Log.rule
    , NoDebug.TodoOrToString.rule
    , NoExposingEverything.rule
    , NoImportingEverything.rule []
    , NoMissingTypeAnnotation.rule
    , NoUnused.CustomTypeConstructors.rule []
    , NoUnused.Dependencies.rule
    , NoUnused.Exports.rule
    , NoUnused.Modules.rule
    , NoUnused.Variables.rule
    ]
```

Finally, run it using

```bash
npx elm-review
```

That should get you started!

I recommend reading the [documentation](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/) before you go too far in, which will give you advice on how to best set up `elm-review` for your project and/or team.

## Feedback and help appreciated

I hope you will try `elm-review` and enjoy it. I spent a lot of time polishing it to give you a great experience using it and writing rules, but there is room for a lot of improvement.

If you would like to help, I would love help to get this tool working in the different editors. You can also publish awesome rules (I'm here for advice or feedback!), or write about the tool in blog posts.

I would love to hear from you if you have constructive criticism, want to help out, want to share what you are using it for, or just want to share that you enjoy it (yes, that helps a lot).

There is an `#elm-review` channel on the Elm Slack where you can do that or ask for help, and you can talk to me privately at `@jfmengels` over there.
