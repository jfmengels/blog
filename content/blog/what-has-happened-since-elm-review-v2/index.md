---
title: What has happened since elm-review v2?
date: '2020-08-26T14:00:00.000Z'
---

I am in the final preparations for a new (and exciting) release of `elm-review`, and I noticed I didn't communicate all the changes that happened since `elm-review` [v2.0.0](/elm-review-v2/) was released back in April 2020. Well, a lot of things happened, so let's get into it.

### Changes in the Elm package

I released 2 minor versions for [`jfmengels/elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/). `2.1.0` was not very interesting for users, as it only added a function meant to enable a feature for the CLI behind the scenes.

[`2.2.0`](https://github.com/jfmengels/elm-review/releases/tag/2.2.0) was more interesting. It introduced 4 new functions: `withExpressionEnterVisitor`, `withExpressionExitVisitor`, `withDeclarationEnterVisitor` and `withDeclarationExitVisitor`.

They are meant to replace `withExpressionVisitor` and `withDeclarationVisitor`. These 2 functions take a `type Direction = OnEnter | OnExit`, which tells you when in the tree traversal the node gets visited. Visiting "on exit" is very useful if you need to do something after having visited the children of the node. In most cases you won't care about this though, but you still had to account for it in order not to report errors twice.

The new `Enter` and `Exit` variants of the different visitors will support the same use-cases, but in a terser way. This will also avoid useless visits and evaluations when you don't care about the exit case, so it is good for performance too. I plan on removing `withExpressionVisitor` and `withDeclarationVisitor` in the next major version, and renaming `withExpressionEnterVisitor` and `withDeclarationEnterVisitor` to take their place. Using these new variants simplifies the code like this:

```elm
-- BEFORE
rule : Rule
rule =
  Rule.newModuleRuleSchema "RuleName" initialContext
    |> Rule.withExpressionVisitor expressionVisitor
    |> Rule.fromModuleRuleSchema

expressionVisitor : Node Expression -> Direction -> Context -> ( List (Error {}), Context )
expressionVisitor node direction context =
    case ( direction, Node.value node ) of
        ( Rule.OnEnter, Expression.FunctionOrValue moduleName name ) ->
            -- do something
        _ ->
            ( [], context )

-- AFTER

rule : Rule
rule =
  Rule.newModuleRuleSchema "RuleName" initialContext
    |> Rule.withExpressionEnterVisitor expressionVisitor
    |> Rule.fromModuleRuleSchema

expressionVisitor : Node Expression -> Context -> ( List (Error {}), Context )
expressionVisitor node context =
    case Node.value node of
        Expression.FunctionOrValue moduleName name ->
            -- do something
        _ ->
            ( [], context )
```

Other than that, the package releases have several times improved performance and improved the test failure messages and assertions. I haven't actually benchmarked the performance much, but I confirmed that the test failure messages have made some people's testing easier.

### Changes in the CLI

There has been quite a lot of performance improvements that I won't go into detail, because I don't have benchmark data. Earlier versions had some stability issues that I have fixed quickly, and I still aim to keep the project bug-free.

A lot more visible (and invisible) changes happened on the CLI side. Just FYI, the versions I will mention henceforth are for the CLI. Oddly enough, the minor versions of the CLI and the Elm package have always been in sync, but that was not done on purpose. 🤷‍♂️

#### Human-readable report

The default output was tweaked to make it nicer to use.

![elm-review snapshot with rule as link](https://pbs.twimg.com/media/EfCaox-XkAM3F3y?format=png)

The errors now contain the line and column of the error (top-right corner), which you can use to go to the exact location of the error in your editor without looking for it (double-click it, copy, and then paste it in your editor's "go to" tool).

There is now a short summary at the end giving you the total number of errors and the total number of affected files.

In terminals that support it (not mine unfortunately...), the rule name becomes a clickable link, which points to the rule's documentation (though only if that rules comes from a dependency). The image is not great, but notice the dotted line under the rule name.

`2.2.0` introduced the `--no-details` flag, which strips out the details of the error messages, which you can use to make the error messages shorter when you are already well acquainted with the rules and their error messages.

#### JSON report

`2.1.0` added the `--report=json` flag, which outputs JSON for tooling to consume. This opened up the possibility of integrating in an editor (I'm working on and off to integrate it in [IntelliJ](https://plugins.jetbrains.com/plugin/10268-elm/)), for [GitHub bots](https://github.com/sparksp/elm-review-action/) and other tools to use `elm-review` internally.

If you want to integrate with `elm-review`, I wrote how to in [this document](https://github.com/jfmengels/node-elm-review/blob/master/documentation/tooling-integration.md).

### new-package and new-rule

`2.2.0` introduced two new subcommands.

`elm-review new-package` creates a new package with the aim to publish `elm-review` rules. The created package comes with the recommendation guidelines, an `elm-review` configuration and tests to help you create a high-quality package helpful to your users. It also comes with a GitHub Actions setup to test your project in CI and [to automatically publish the package](https://github.com/dillonkearns/elm-publish-action/) when the version is bumped. Note: it will become even better and more complete with the next release 😉

`elm-review new-rule` creates a source file and a test file for a new rule. You can use this inside your project's review configuration to create a custom rule or inside a review package. In review packages, it will automatically add the rule to the `exposed-modules` in the `elm.json` file and add the rule in the README. The rule comes with the recommended documentation guidelines.

### Package eco-system

I created [elm-review-rule-ideas](https://github.com/jfmengels/elm-review-rule-ideas), where people can submit rule ideas and ask for feedback, help or tips for those ideas. If you are interested in contributing to the Elm or `elm-review` ecosystems, or simply in playing around with `elm-review`, you can take a rule idea from there and create/publish it 🧙.

Since v2, quite a few people created and published rules to the package registry. I will start with updates from my own packages, which I know best, and then mention a few others I think are really nice and/or can be used by a lot of people.

Just note that I recently renamed all of my own packages. I used to name them `review-xyz`, but most of the published packages went with `elm-review-xyz`. To be consistent and a bit more explicit, I recently renamed them all to this naming convention, and packages created using `elm-review new-package` will also be guided towards that naming convention. I won't mention the package further as it received no changes, but `review-debug` was renamed to `elm-review-debug`.

#### elm-review-unused (previously review-unused)

[This package](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/)'s purpose is to report all unused/dead code in your Elm code, and proposing automatic fixes where it makes sense.

[`NoUnused.Exports`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports), which reports exposed elements that are never used outside the module (don't worry, it doesn't report problems for exposed modules inside package projects!), got an automatic fix. Running `elm-review --fix-all` with `NoUnused.Variables` and `NoUnused.Exports` enabled does wonders for removing a lot of dead code 🧹. On a 160K LOC project I work on, this combo applied hundreds of fixes, ultimately uncovering and removing 4500 LOC! 🤯 I recommend running with **only** those two rules enabled if you're doing this for the first time, because it can take a while especially if you have other rules enabled. Consecutive fixes is not well optimized at the moment, but I see ways of drastically improving this in the future.

[Phill Sparks (@sparksp)](https://github.com/sparksp/) wrote 2 rules 💪 that were added to the package: [`NoUnused.Parameters`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Parameters) and [`NoUnused.Patterns`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Patterns), which help a lot with uncovering unused code and simplifying your codebase.

#### elm-review-common (previously review-common)

The name for [this package](https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/) is quite generic, and I think that in time its rules will move towards separate packages to be grouped with other rules that make more sense.

When 2.0.0 was released, it contained 3 rules: [`NoExposingEverything`](https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoExposingEverything) (no `exposing (..)` in the module definition), [`NoImportingEverything`](https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoImportingEverything) (no `exposing (..)` for an import) and [`NoMissingTypeAnnotation`](https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoMissingTypeAnnotation).

2 more were published since then. First, [`NoMissingTypeAnnotationInLetIn`](https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoMissingTypeAnnotationInLetIn), which is the same thing as `NoMissingTypeAnnotation`, but for `let in` expressions. Second, [`NoMissingTypeExpose`](https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoMissingTypeExpose) which again is thanks to [@sparksp]([https://github.com/sparksp/) and prevents from exposing a function which uses a non-exposed type. If you did that, users would be prevented from either using the function or adding a type annotation for a vlaue of that type.

#### elm-review-the-elm-architecture (previously review-tea)

[This one](https://package.elm-lang.org/packages/jfmengels/elm-review-the-elm-architecture/latest/) is new. It contains the following rules:

- [`NoMissingSubscriptionsCall`](https://package.elm-lang.org/packages/jfmengels/elm-review-the-elm-architecture/1.0.0/NoMissingSubscriptionsCall) - Reports likely missing calls to a `subscriptions` function.
- [`NoRecursiveUpdate`](https://package.elm-lang.org/packages/jfmengels/elm-review-the-elm-architecture/1.0.0/NoRecursiveUpdate) - Reports recursive calls of an `update` function.
- [`NoUselessSubscriptions`](https://package.elm-lang.org/packages/jfmengels/elm-review-the-elm-architecture/1.0.0/NoUselessSubscriptions) - Reports `subscriptions` functions that never return a subscription.

#### elm-review-documentation (previously review-documentation)

[This one](https://package.elm-lang.org/packages/jfmengels/elm-review-documentation/latest/) came out shortly after the `2.0.0` release. It comes with a single rule: [`Documentation.ReadmeLinksPointToCurrentVersion`](https://package.elm-lang.org/packages/jfmengels/elm-review-documentation/1.0.0/Documentation-ReadmeLinksPointToCurrentVersion). It reports links in the `README.md` that do not point to the current version of the package. I personally use this one to make sure that the links to functions/types/rules in my packages target the current version of the package, and not `latest` where they may have disappeared in a new major version or is a relative link [that will not work on GitHub](https://discourse.elm-lang.org/t/problems-with-readmes-in-elm-packages/5396).

I wanted to focus on this package after `2.0.0`, because I think there is so much potential to help (at least) package authors to build great documentation with less maintenance work, but other things felt more pressing in the end. With rules like the one above we can make it so that:

- links inside documentation are valid: no more referring to a non-existent/disappeared type/function/section
- there is no empty documentation (`{-| -}`) anywhere where documentation is needed
- applications have valid and up-to-date documentation, as the Elm compiler only enforces documentation constraints for packages
- images in the documentation will forever work (using the same technique as the rule above), and not disappear once the image disappears from master
- links to dependencies refer to the documentation of the version in `elm.json`, not `master` which gets out of date

#### Packages from the community

Not to be presented anymore, [@sparksp](https://github.com/sparksp/) wrote several packages (did I mention he wrote that [GitHub bot](https://github.com/sparksp/elm-review-action/) for `elm-review` I linked to above too?).

[`sparksp/elm-review-forbidden-words`](https://package.elm-lang.org/packages/sparksp/elm-review-forbidden-words/latest/) contains the [`NoForbiddenWords`](https://package.elm-lang.org/packages/sparksp/elm-review-forbidden-words/latest/NoForbiddenWords) rule, which forbids certain (configurable) words in Elm comments, README and `elm.json`.

[`sparksp/elm-review-ports`](https://package.elm-lang.org/packages/sparksp/elm-review-ports/latest/) contains rules to prevent JavaScript runtime errors with [`NoDuplicatePorts`](https://package.elm-lang.org/packages/sparksp/elm-review-ports/latest/NoDuplicatePorts) and [`NoUnusedPorts`](https://package.elm-lang.org/packages/sparksp/elm-review-ports/latest/NoUnusedPorts) (which warns about a common cause of frustration for beginners 🤬).

He also wrote but hasn't yet published [`sparksp/elm-review-imports`](https://github.com/sparksp/elm-review-imports), with [`NoInconsistentAliases`](https://github.com/sparksp/elm-review-imports/blob/master/src/NoInconsistentAliases.elm) which enforces consistent aliases for all your imported modules (with several ways of configuration to make most of you happy), and [`NoModuleOnExposedNames`](https://github.com/sparksp/elm-review-imports/blob/master/src/NoModuleOnExposedNames.elm) which forbids using the module name for types/values that have been imported and added to the scope. The package is unpublished at the moment, but you can copy the rules into your review configuration directory if you wish to use them anyway.

[Rita](https://github.com/lxierita) (@langxie on Slack) wrote [`NoTypeAliasConstructorCall`](https://package.elm-lang.org/packages/lxierita/no-typealias-constructor-call/latest/NoTypeAliasConstructorCall) which favors `{ foo = "bar" }` over `Foo "bar"` where `Foo` is a type alias. She wrote this while learning Elm, and I think it will be useful to the community, as I asked around and no-one seems to like to use the reported syntax.

[Ilias Van Peer](https://github.com/zwilias) published several packages under [TruQu](https://github.com/truqu)'s name: [`NoBooleanCase`](https://package.elm-lang.org/packages/truqu/elm-review-nobooleancase/latest/NoBooleanCase), [`NoRedundantConcat`](https://package.elm-lang.org/packages/truqu/elm-review-noredundantconcat/latest/NoRedundantConcat) and [`NoRedundantCons`](https://package.elm-lang.org/packages/truqu/elm-review-noredundantcons/latest/NoRedundantCons). There is also [`NoLeftPizza`](https://package.elm-lang.org/packages/truqu/elm-review-noleftpizza/latest/NoLeftPizza) which you can configure to forbid `<|` either altogether (which they wanted for their team) or only where it is superfluous (which is my preference).

There are other packages/rules I didn't go into. Search for "review" in the package registry or find them using the [GitHub `elm-review` topic](https://github.com/topics/elm-review).

### What next?

Well, before going further, I would like to thank all those who helped, contributed, proposed and participated in any way, which really improved the overall quality of the tool and ecosysteme around it. It also made this adventure of mine much less lonely. I have been working on this project almost non-stop for more than a year already, so it felt really nice to have some company 😄

Special thanks to Phill Sparks (unsurprisingly at this point), Martin Stewart, Ilias Van Peer, Simon Lydell and the whole GlobalWebIndex team! ❤️

As I said, I am working on an exciting release. Here's a sneak peak:

```bash
cd an-elm-project
npx elm-review@beta --template jfmengels/elm-review-unused/example
# or even
npx elm-review@beta --template jfmengels/elm-review-unused/example --fix-all
# 😱
```

I discuss new features and `elm-review`-related things in the `#elm-review` Elm Slack, and in the [Incremental Elm Discord](https://discord.gg/H9Q34B)'s `#elm-review` channel, so more sneak peeks are available there.

I am not entirely sure what I will be working on after the next release. I have a very long list of tasks to work on, but writing them down in public spaces consumes a lot of time, so they're mostly in my local notebook. I think the priority will likely be the IntelliJ integration, and I would love people to help out with that.

If you'd like to contribute, there are several ways:

- Write rules. If you have no inspiration, find a rule idea over at [elm-review-rule-ideas](https://github.com/jfmengels/elm-review-rule-ideas). You can also pitch in new ideas or comment on existing ones there.
- Make PRs to fix issues in any of the `elm-review` repositories, or just help manage/triage the issues (not that there are that many, most projects are written in Elm 😉).
- Come to one of the channels mentioned above and say you'd like to help out, or just participate in the discussions. Getting feedback for ideas is so important!
- Come tell me you like/enjoy the tool. It means the world to me to hear that.
- Support me financially. I opened a [GitHub sponsors page](https://github.com/sponsors/jfmengels) where you can help me out. I would love to be able to work on this project and similar future endeavors full-time (one day!), or with at least a better life balance. Oh, and you might as well thank my girlfriend for being okay with me spending so much time on this 😁

Take care, and you'll read from me soon!
