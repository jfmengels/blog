---
title: What has happened since elm-review v2?
date: '2020-08-19T18:00:00.000Z'
---

I am in the final preparations for a new (and exciting) release of `elm-review`, and I noticed I didn't communicate all the changes that happened since `elm-review` v2.0.0 was released back in April 2020. Well, a lot of things happened, so let's get into it.

### Changes in the Elm package

I released 2 minor versions for [`jfmengels/elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/). `2.1.0` was not very interesting for users, as it only added a function meant to enable a feature for the CLI behind the scenes.

[`2.2.0`](https://github.com/jfmengels/elm-review/releases/tag/2.2.0) was more interesting. It introduced 4 new functions: `withExpressionEnterVisitor`, `withExpressionExitVisitor`, `withDeclarationEnterVisitor` and `withDeclarationExitVisitor`.

They are meant to replace `withExpressionVisitor` and `withDeclarationVisitor`. These 2 functions take a `type Direction = OnEnter | OnExit`, which tells you when in the tree traversal the node gets visited. Visiting "on exit" is very useful if you need to do something after having seen the children of the node. In most cases, we don't care about this, but you still had to check its value.

The new `Enter` and `Exit` variants of the different visitors will support the same use-cases, but in a terser way. This will also avoid useless visits, so it is good for performance too. I plan on removing `withExpressionVisitor` and `withDeclarationVisitor` in the next major version, and renaming `withExpressionEnterVisitor` and `withDeclarationEnterVisitor` to take their place. Using these new variants would simplify the code like this:

```elm
-- BEFORE
rule : Rulerule =
  Rule.newModuleRuleSchema "RuleName" initialContext
    |> Rule.withExpressionVisitor expressionVisitor
    |> Rule.fromModuleRuleSchema

expressionVisitor : Node Expression -> Direction -> Context -> ( List (Error {}), Context )
expressionVisitor node direction context =
    case ( direction, Node.value node ) of
        ( Rule.OnEnter, Expression.FunctionOrValue moduleName name ) ->
            -- do something
        _ ->
            -- do nothing

-- AFTER

rule : Rulerule =
  Rule.newModuleRuleSchema "RuleName" initialContext
    |> Rule.withExpressionEnterVisitor expressionVisitor
    |> Rule.fromModuleRuleSchema

expressionVisitor : Node Expression -> Context -> ( List (Error {}), Context )
expressionVisitor node context =
    case Node.value node of
        Expression.FunctionOrValue moduleName name ->
            -- do something
        _ ->
            -- do nothing
```

Other than that, the package releases have several times improved performance and improved the test failure messages and assertions. I haven't actually benchmarked much, but I confirmed that the test failure messages have made some people's testing easier.

### Changes in the CLI

There has been quite a lot of performance improvements that I won't go into detail, because I don't have benchmark data. Earlier versions had some stability issues that I have fixed quickly, and I still try to get the project bug-free .

A lot more visible (and invisible) changes happened on the CLI side.

#### Human-readable report

The default output was tweaked to make it nicer to use.

The errors now contain the line and column of the error, which you can use to go to the exact location of the error in your editor without looking for it.

There is now a short summary at the end giving you the total number of errors and the total number of affected files.

In terminals that support it (not line unfortunately...), the rule name becomes a clickable link, which points to the rule's documentation (though only if that rules comes from a dependency).  
(Todo image)

`2.2.0` introduced the `--no-details` flag, which strips out the details of the error messages, which you can use to make the error messages shorter when you are already well acquainted with the rules and their error messages.

#### JSON report

`2.1.0` added the `--report=json` flag, which outputs JSON for tooling to consume. This opened up the possibility of integrating in an editor (I'm working on and off to integrate it in IntelliJ), for [GitHub bots](https://github.com/sparksp/elm-review-action/) and other tools to use `elm-review` internally.

If you want to integrate with `elm-review`, I wrote how to in [this document](https://github.com/jfmengels/node-elm-review/blob/master/documentation/tooling-integration.md).

### new-package and new-rule

`2.2.0` introduced two new subcommands.

`elm-review new-package` creates a new package with the aim to publish `elm-review` rules. The created package comes with the recommendation guidelines, an `elm-review` configuration and tests to help you create a high-quality package helpful to your users. It also comes with GitHub Actions setup to test your project in CI and [to automatically publish the package](https://github.com/dillonkearns/elm-publish-action/) when the version is bumped. Note: it will become even better and more complete with the next release 😉

`elm-review new-rule` creates a source file and a test file for a new rule. You can use this inside your project's review configuration to create a custom rule or inside a review package. It will automatically add the rule to the `exposed-modules` in the `elm.json` file, and if it looks like a package created by `new-package`, the README will be updated to respectively expose and mention the rule. The rule comes

### Package eco-system

I created [elm-review-rule-ideas](https://github.com/jfmengels/elm-review-rule-ideas), where people can submit rule ideas, ask for feedback, help or tips. If you are interested in contributing to the Elm or `elm-review` ecosystems, or simply in playing around with `elm-review`, you can take a rule idea from there and create/publish it 🧙.

Since v2, quite a few people created and published rules to the package registry. I will start with updates from my own packages, which I know best, and then mention a few others I think are really nice and/or can be used by a lot of people.

Just note that I recently renamed all of my own packages. I used to name my packages `review-xyz`, but most of the published packages went with `elm-review-xyz`. To be consistent and a bit more explicit, I recently renamed them all to this naming convention, and packages created using `elm-review new-package` will also be guided towards that naming convention. I won't mention it further as it received no changes, but `review-debug` was renamed to `elm-review-debug`.

#### elm-review-unused (previously review-unused)

This package's purpose is to report all unused/dead code in your Elm code, and proposing automatic fixes where it makes sense.

[`NoUnused.Exports`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports), which reports exposed elements that are never used outside the module (don't worry, it doesn't report problems for exposed modules inside package projects!), got an automatic fix. Running `--fix-all` with `NoUnused.Variables` and `NoUnused.Exports` enabled do wonders for removing a lot of dead code 💅. On a 160K LOC project I work on, this combo applied hundreds of fixes, ultimately uncovering and removing 4500 LOC! 🧹 I recommend running with only those two rules enabled if you're doing this for the first time, because it can take a while especially if you have other rules enabled (32 minutes in my case!). Consecutive fixes is not well optimized at the moment, but I see ways of drastically improving this in the feature.

[Phill Sparks (@sparksp)]([https://github.com/sparksp/) wrote 2 rules that were added to the package: [`NoUnused.Parameters`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Parameters) and [`NoUnused.Patterns`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Parameters) 💪

#### elm-review-common (previously review-common)

The name for this package is quite generic, and I think that in time its rules will move towards separate packages to be grouped with other rules that make more sense.

When 2.0.0 was released, this package contained 3 rules:

- https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoExposingEverything
- https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoImportingEverything
- https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoMissingTypeAnnotation

2 more were published since then.

- https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoMissingTypeAnnotationInLetIn, which is the same thing as `NoMissingTypeAnnotation`, but for `let in` expressions.
- https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoMissingTypeExpose again, thanks to [@sparksp]([https://github.com/sparksp/)!

Todo common  
NoMissingtypeanotationinletin  
Todo documentation  
Readme links (plan to make it more maintainable to do documentation for all Elm applications and packages)  
Todo tea
elm-review-ports
elm-review-imports

TODO

- Renaming of packages
- New functions, etc
- Other people's packages/rules.
- elm-review-rule-ideas

---

Today I am very excited to release `elm-review` 2.0.0 and to share its new features!

tl;dr: Here is the list of the introduced features:

#### New review capabilities!

- Project rules!
- Reporting errors for `elm.json`
- Reading the dependencies' `docs.json` file
- Visiting the [README.md](http://README.md) file
- Visiting the comments and documentation
- New helpers for creating rules

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

I put a lot of effort into making a [**very nice API**](https://package.elm-lang.org/packages/jfmengels/elm-review/2.0.0/Review-Rule) for you to use ([here](https://github.com/jfmengels/review-simplification/blob/master/src/NoBooleanCaseOf.elm) [are](https://github.com/jfmengels/review-debug/blob/master/src/NoDebug/Log.elm) [some](https://package.elm-lang.org/packages/jfmengels/elm-review/2.0.0/Review-Rule#withSimpleExpressionVisitor) [examples](https://package.elm-lang.org/packages/jfmengels/elm-review/2.0.0/Review-Rule#withSimpleImportVisitor)), even going through the lengths of discovering new Elm techniques (expect to see blog posts on the **phantom builder pattern** on this blog), and I am very happy with the result!

To some, `elm-review` looks like a linter. Which isn't necessarily wrong, since you can enable rules that help improve the quality of your code and enforce coding conventions for your team.

If you dive a bit further, you will find out that it can create new guarantees that the Elm compiler can not give you.

For instance you can write rules that

- report when you [pass values outside of 0-255 to `Css.rgb255`](https://package.elm-lang.org/packages/folq/review-rgb-ranges/latest/)
- give an error if any `Regex.fromString` calls have invalid regexes (for literal strings)

With `elm-review` v1, the analysis broke down as soon as a problem spanned multiple modules though, but that's now solved by:

## Project rules!

In `elm-review` version 1, `Elm Analyse`, `ESLint` and a lot of similar tools for other languages, the analysis is scoped to a single file.

This means that when a rule has finished looking at module A, and starts looking at module B, it forgets everything about module A. This makes a lot of useful analysis untenable, like:

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
- Report when `Html.lazy` is used incorrectly
- Report when a variable that should contain all the possible variants of a custom type is missing a variant
- Report when a module uses another module's `update` function but not the `subscription` function
- Report unused CSS classes from your CSS files (would require you to generate an Elm file from the CSS files in the configuration folder)

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

## Visiting the [README.md](http://README.md) file

The README is an integral part of the project, especially for packages. For package authors and their users, it is important that everything in there is correct.

This version introduces a visitor for the README, which allows you to collect data and report errors on it. Those errors can be fixed automatically.

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

## New helpers for creating rules

Some tasks, like targeting a specific function, are harder than they should be. For instance, if you want to forbid `Foo.bar`, you'll need to handle multiple ways that the function can be called and imported, which is tedious and error-prone.

I started writing a helper named [`elm-review-scope`](https://github.com/jfmengels/elm-review-scope) that deals with this problem, and makes some tasks as easy as they should be.

I am not making it part of `elm-review` nor publishing it as a separate package though, because the API is still unstable.

## Much faster, and with a watch mode

Version 1 focused on usability and on validating that `elm-review` was a good solution for these problems. Performance was secondary.

With version 2, performance was a focus, and the results are really good. Parsed files are now cached, so the initial run is still a bit slow, but subsequent runs are faster by several times.

There is also a **watch mode** where the changes feel instantaneous.

And I am sure we can do much better for future versions! The work done here should help pave the way to having editor support.

## Configuring exceptions

When you enabled a rule in version 1, you weren't able to ignore any errors that it reported. You had to edit or fork the rule to ignore the cases you wanted to ignore.

The idea was to avoid ignoring errors locally through a comment of some sort, like what happens all over the place with `ESLint` ([which leads to all sorts of problems](https://github.com/jfmengels/elm-review/#is-there-a-way-to-ignore-an-error-or-disable-a-rule-only-in-some-locations)). Instead users should [think on whether enabling a rule is a good idea](https://github.com/jfmengels/elm-review/#when-to-write-or-enable-a-rule) in the first place. And I still stand by these choices!

But there are places where it's reasonable to ignore review errors, namely for generated code and vendored code, and for introducing a rule gradually when there are too many errors. Sometimes, it also makes sense to have tests follow slightly different rules.

In these cases, you can [configure your rules](https://package.elm-lang.org/packages/jfmengels/elm-review/2.0.0/Review-Rule#configuring-exceptions) to not apply on a section on some directories or some files.

## fix-all flag

Version 1 had a `fix` flag, where it would propose automatic fixes for some of the problems that it knew how to fix, and you could accept or refuse them.

For some, it was very annoying to go through all the fixes as this could be long and tedious when you had a lot of errors.

So this version comes with a `--fix-all` where you get one big diff between the current source and the one where all fixes have been applied, and you can accept or refuse it.

I do not believe automatic fixes to always be perfect, and I know that there are some kinks in a few of the ones I wrote, so please be cautious when looking at the before/after diff and don't commit the changes blindly.

## Better default folder structure

The default structure version 1 created for you didn't allow you to run tests for your rules due to conflicts with `elm-test`.  
The "review application" that you now get from running `elm-review init` is structured in a way that will make tests work out of the box.

`elm-review init` now adds the dependencies needed to write rules by default too.

## Tests included by default

The `tests/` directory is now included by default. Since they are part of an Elm project, it makes sense to review them too.

## More rules to start with

Until now, the catalog of rules has been quite small, and I can understand that for many people this was a blocker for adoption.

Along with this release, I am publishing more rules than the 3 I had previously written. You can find them by searching for `jfmengels/review-` in [the packages website](https://package.elm-lang.org) (and in general by looking for `/review-` for other people's packages), but among them are:

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

Here are the things that `Elm Analyse` has and `elm-review` does not:

- A web interface, but `elm-review` has a similar CLI watch mode.
- Showing the graph of modules, but I don't really see the value that brings.
- Showing when dependencies can be updated. I see the value, but I don't think it is a good fit for the tool.
- Editor support. I definitely see the value, let me know if you want to help out with that!

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

and then add these rules to your configuration (FYI, these do not include the ones from [`jfmengels/review-documentation`](https://github.com/jfmengels/review-documentation) nor [`jfmengels/review-debug`](https://github.com/jfmengels/review-simplification))

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
