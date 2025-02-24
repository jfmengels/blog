---
title: Gaining insight into your codebase with elm-review
slug: elm-review-insights
published: "2022-12-06"
---

A few weeks ago, I announced a new version of [`elm-review`](elm-review.com). In [part 1](/much-faster-fixes), I wrote about how automatic fixes are now **much, much faster** than before.

In this second and final part (*disappointed audience sighing*), I will talk about an entirely new feature of `elm-review`, which allows you to gain arbitrary insight into your codebase.

Do you wish to have an overview of your codebase? Which modules import which? Do you wish to know how complex your codebase is?
Create diagrams of how your project works?

Well, you'll have the tools for that now.

## Context is important

First, a bit of context... about context.

`elm-review` is a static analysis tool that reports problems in Elm codebases according to a set of rules that you can
choose from the Elm package registry, or write yourself.

In order to make the most accurate analysis possible — report as many of the problems we possibly can while reporting no
false positives — rules need to collect information, which I call "context". And that is because the devil is in the details.

Let's say we wish to have a tool that reports references to `Html.button` to have people use
`BetterHtml.button` instead.

We could use a tool like `grep` to go through the project's source code and find the references to `Html.button`, like `grep -e 'Html.button' src/**/*.elm`. But that won't work all that well.

```elm
-- Found a reference!
import Html
Html.button [] [] -- ✅

-- Not found
import Html exposing (button)
button [] [] -- ❌

-- Also not found
import Html as H
H.button [] [] -- ❌

-- Nope. Also, this may depend on what
-- is in your dependencies and/or modules
import Html exposing (..)
button [] [] -- ❌

-- Found a reference, but not for the
-- function we're interested in
import BetterHtml as Html
Html.button [] [] -- ❌

-- No, we don't want to catch things in text
someText = "I love Html.button!" -- ❌

-- Nor in comments
module BetterHtml exposing (button)
{-| Better alternative to Html.button -- ❌
-}
button = -- ...
```

Naively searching for `Html.button` will lead to very poor results. It will miss a lot of the references we're interested in,
and report a bunch of results that are not references or not the ones we're interested in. If we search for `button`
instead of `Html.button`, then we'll find more references, but also a lot more unrelated ones.

Some tools — such as [`comby`](https://comby.dev/) and
[`tree-grepper`](https://discourse.elm-lang.org/t/search-elm-code-and-other-things-with-tree-grepper/7723) — are more
code-aware than `grep`, and they will do a better a job at this task — such as not reporting references in strings or
comments —, but probably not without mistakes. I imagine `tree-grepper` could potentially find references correctly, but
be limited in other kinds of analysis (finding unused type variants for instance).

What happens in one part of the file can impact what happens in another part of the file, and the same thing is true at
the codebase level as well. Stateless tools like `grep`, `comby` or `tree-grepper` are awesome
(and very fast!) but as soon you need a bit of context or to combine pieces of information to make something of what has
been found, you'll need to add in more logic through external tools or scripts.

If you wish to gain insight into a project, not being able to get this level of nuance can make or break the results, or
experience, of your analysis.

But this is something that `elm-review` does very well. Targeting a specific function for instance is something the tool
does flawlessly and makes quite easy.

Because a lot of analysis requires information that needs to be collected, I made sure that `elm-review` has a very nice
way of traversing a project and gathering that context. Which as I said before allows it to report errors very accurately.

But while you can easily collect all that information, you can **only** use it to report errors. And that's kind of a shame.

# Introducing data extractors

Starting from `jfmengels/elm-review` v2.10.0, `elm-review` rules can define a "data extractor" using [`Rule.withDataExtractor`](https://package.elm-lang.org/packages/jfmengels/elm-review/2.10.0/Review-Rule/#withDataExtractor).
This makes it possible to transform the collected data (the "project context" in our terminology) into arbitrary JSON.

As a (too) trivial example, below is a rule ([also to be found here](https://elm-doc-preview.netlify.app/ModuleNameToFilePath?repo=jfmengels%2Felm-review-random-insights&version=main))
that goes through the project and outputs a mapping of the module name of Elm files to their file path. This is what the
output would look like:

```json
{
  "Api": "src/Api.elm",
  "Article": "src/Article.elm",
  "Article.Body": "src/Article/Body.elm",
  "Asset": "src/Asset.elm",
  "Page.Article": "src/Page/Article.elm",
  "Page.Article.Editor": "src/Page/Article/Editor.elm",
  "Page.Profile": "src/Page/Profile.elm",
  "...":  "...and some more"
}
```

and the rule's implementation:

```elm
module ModuleNameToFilePath exposing (rule)

import Dict exposing (Dict)
import Json.Encode
import Review.Rule as Rule exposing (Rule)

rule : Rule
rule =
    Rule.newProjectRuleSchema "ModuleNameToFilePath" initialContext
        -- Dummy visitor. There is a requirement to at least have a
        -- visitor. I think elm-review has evolved past this need
        -- since we can now collect data through different means.
        -- But that's a breaking change, so it will be simpler in v3.
        -- In a real use-case, you'd likely really collect things here.
        |> Rule.withModuleVisitor (\schema -> schema |> Rule.withSimpleModuleDefinitionVisitor (always []))
        |> Rule.withModuleContextUsingContextCreator
            { fromModuleToProject = fromModuleToProject
            , fromProjectToModule = Rule.initContextCreator (\_ -> ())
            , foldProjectContexts = foldProjectContexts
            }
        |> Rule.withDataExtractor dataExtractor
        |> Rule.fromProjectRuleSchema

{-| The data we're going to collect: A dictionary from module name to file path. -}
type alias ProjectContext =
    Dict String String

{-| Empty dict to start with. -}
initialContext : ProjectContext
initialContext =
    Dict.empty

{-| Collect the information we're interested in. -}
fromModuleToProject : Rule.ContextCreator () ProjectContext
fromModuleToProject =
    -- Requesting the module name and file path,
    -- and combining them together into a Dict singleton
    Rule.initContextCreator
        (\moduleName filePath () ->
            Dict.singleton (String.join "." moduleName) filePath
        )
        |> Rule.withModuleName
        |> Rule.withFilePath

{-| Combine the collected context for two files into one.
Basically combine the resulting dictionary for each.

This will be used to combine the project contexts of all the files into a single one.
-}
foldProjectContexts : ProjectContext -> ProjectContext -> ProjectContext
foldProjectContexts =
    Dict.union

{-| Turn the combined project context into arbitrary JSON.
In this case, just an object with the module names as the keys
and the file paths as the values.
-}
dataExtractor : ProjectContext -> Json.Encode.Value
dataExtractor projectContext =
    Json.Encode.dict identity Json.Encode.string projectContext
```

This is likely not a rule that you will end up using as its utility is limited, but I hope this shows the general feel.
(That said, this example is maybe a bit weird. Because it doesn't really visit Elm files, it does look a bit alien even to me)

If you're familiar with writing `elm-review` rules, it's going to be exactly the same but with an additional data extractor function.
If you're familiar with Elm but not `elm-review`, it's going to be a new API to learn, but it will be very Elm-like,
especially when compared to learning a new DSL like the alternatives I mentioned.

## Usage

The way to run the rule above and get the extracted information is by adding the rule to your configuration and then running
the CLI with the following flags:

```bash
elm-review --report=json --extract
```

Without these flags, `elm-review` will not call the data extractor function. Since it wouldn't make sense to view the JSON
output of a rule when looking at the regular output (at least, I haven't figured a good way), you need the `--report=json` flag.
And since that reporting format is used by IDEs, the `--extract` option is opt-in to avoid them incurring a performance penalty.

Running the above will result in JSON that looks like the following:

```json
{
  "errors": [],
  "extracts": {
    "Name.Of.A.Rule": "arbitrary string",
    "Name.Of.Other.Rule": {
      "arbitrary": "json"
    },
    "...": "..."
  }
}
```

To access the output of a rule named `ModuleNameToFilePath`, you will want to read the value under `extracts` then under
`ModuleNameToFilePath`. My current approach which works quite well is to pipe the result of `elm-review` into [`jq`](https://stedolan.github.io/jq/), a tool to manipulate JSON through the command-line, like this:

```bash
elm-review --report=json --extract | jq -r '.extracts.ModuleNameToFilePath'
```

Note that if you run the above and get `null` as the output, then it's likely you have an error while running `elm-review`
or that the rule has reported an error that prevented the data extractor from running (using
[`Rule.preventExtract`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#preventExtract)).
Run the tool again without `--report=json` to see what went wrong.

You can also access that data through a Node.js script or other tools that you like to use to manipulate JSON.


## Applications

There are many ways that this can be useful. From simply counting the number of lines in a codebase to making dashboards
worth of insightful metrics combined with versioning history, or through the creation of diagrams that can help explain
parts of your codebase.

A simple example is to draw the import graph of modules (example for [elm-spa-example](https://github.com/rtfeldman/elm-spa-example)).

[![](/images/elm-review-insights/import-graph.svg)](./import-graph.svg)

You can try this out on your project with the following commands:

```bash
elm-review --template SiriusStarr/elm-review-import-graph/preview --extract --report=json | jq -r '.extracts.ExtractImportGraph.onlineGraph'
```

which will give you a link to preview the generated graph. The online viewer might not work out if you try this on a
project that is too large though, in which case you can generate the image directly using the following command (requires the [dot CLI](https://graphviz.org/download/)):

```bash
elm-review --template SiriusStarr/elm-review-import-graph/preview --extract --report=json --rules ExtractImportGraph | jq -r '.extracts.ExtractImportGraph.graph' | dot -Tsvg -o import-graph.svg
```

(Thank you [@SiriusStarr](https://github.com/SiriusStarr) for the help on this rule ❤️)

Creating the import graph was a feature that [Elm Analyse](https://stil4m.github.io/elm-analyse/) provided. I didn't intend to be able to supplant nearly every
feature that it could do, but it's interesting to see `elm-review` being able to do so in the end.

And while Elm Analyse only provided a DOT graph specification (not technically drawing it), with `elm-review` this is
all customizable. If you prefer a [Mermaid diagram](https://mermaid-js.github.io/mermaid/) for instance, you could change
the rule to output that format instead.

You can also adapt the rule to prune some folders you don't care about, make clusters of related modules, etc.
If you do so, you can then generate a graph explaining the rough structure of your codebase in a way that works for
onboarding new colleagues. You can even automate this process to make sure you always have an up-to-date graph.

Similarly, you can use this to generate documentation. I have an unpolished [proof-of-concept rule](https://elm-doc-preview.netlify.app/ExtractDocsJson?repo=jfmengels%2Felm-review-random-insights&version=main)
for generating the `docs.json` file of an Elm project. That is the file that the Elm compiler generates for packages and
that gets used to display their documentation. You could change that rule in a way that extracts the information you
wish to document and then inject into your favorite tool to visualize documentation.

Push it a step further, and you can generate Elm code. Extract Elm code as a JSON string (manually or using
[`elm-codegen`](https://package.elm-lang.org/packages/mdgriffith/elm-codegen/latest/)) and you can do very powerful things.

I have adapted the [`NoUnapprovedLicense`](https://package.elm-lang.org/packages/jfmengels/elm-review-license/latest/NoUnapprovedLicense)
rule — which reports when you use non-allowed licenses for your dependencies — so that you can use it as an insight rule
to collect the licenses that your dependencies are using. This can be useful for companies that need to indicate the
licenses that they're using, because they can now automate this task (at least for the Elm dependencies).


### Non-enforceable rules

Sometimes people think of `elm-review` rules that are in practice not enforceable, at least not with `elm-review`'s
philosophy, because these tend to have many edge cases. You might still want to be made aware of these. Now you can use
the same tool to either enforce it, or to get insight as to where in the codebase something bad is happening and react
to it through different means.

That means that you can start writing an `elm-review` rule, and if or when you notice that it won't work out as a rule,
you can convert it to an insight rule to find the problematic pieces of code, or maybe even enforce it through a
different system (which I'd love to hear about).

A crude example is [this `FindUntestedModules` rule](https://elm-doc-preview.netlify.app/FindUntestedModules?repo=jfmengels%2Felm-review-random-insights&version=main)
that tells you which files are not being imported by tests. Is this something you wish to enforce in practice? Probably
not. Can it be useful to figure out ways to improve your codebase? Absolutely.

A more practical example is the cognitive complexity rule, which I dedicated [a previous blog post](/cognitive-complexity) to. I
don't believe that this rule — which aims to help reduce the complexity of functions — has had a lot of success, partially
because it needed to be configured with an arbitrary complexity threshold which has felt odd or impractical to many.
I have added a data extractor to this rule, meaning you can now use it
[as an insight rule](https://package.elm-lang.org/packages/jfmengels/elm-review-cognitive-complexity/latest/CognitiveComplexity#use-as-an-insight-rule)
to see the complexity of each function in your codebase.

You can use this data to explore the more complex functions or modules, and make a plan on how to reduce the complexity
of your codebase.

### Larger overview tools

In other communities, there are commercial heavy-looking products analyzing codebases, providing an overview of the codebase,
complexity metrics, showing the hot spots, indicating code smells, and more. I think that this new feature can help make
these kinds of tools.

## Configuration organization

So how or where should you enable these rules? Well, if some rules that you use to enforce something also happen to have
a data extractor, it's fine to have those rules in the usual configuration in `review/`.

If you do have a `review/` folder but are not interested in having these rules run to report issues (because they don't
report issues at all for instance), then adding them to your regular configuration will only serve to slow `elm-review` down.

I'm not entirely sure what the best approach for using this is yet, but I presume that a reasonable approach will be to
have a separate `elm-review` configuration in an `insight/` folder, and to use that one when you wish to get the
specific insight, which you can specify using the `--config` flag.

```bash
# Create an empty configuration folder for getting insight
elm-review init --config insight/

# Use the insight configuration
elm-review --config insight/ --report=json --extract
```

Let me know what you think, and if you find different setups to work better, let me know!


## Open to ideas

The API for extracting data might feel a bit bare-bones at the moment. To use this new feature, you almost have to use
additional tools like `jq`, `dot` or custom scripts.

This is partially done on purpose because I would like to see how people use this feature before adding "API-sugar" that
might end up being unnecessary or not useful. The other part is that I have had trouble figuring out how to present the
data in a nice and general way.

For instance, I would love to see people run this in `--watch` mode (or through their IDEs) to draw ASCII diagrams that
easily explains something complex, like representing the state machine of a TEA module or of a parser.

But so far I haven't yet been able to figure out how to present that nicely (without using additional tools), along with
the results of other rules. I'm very open to ideas for this because I think that this could open up to very interesting
new things!

## Testing data extracts

`elm-review`'s testing module has always aimed at being very exhaustive in its checks. If your rule reports an error in a
given test case, then you need to provide an expectation of the specific message, details and location of the error.
Should it provide automatic fixes, then you need to provide the expected source code after the fix. And so on.

While it may feel annoying, I believe that this has worked out very well for the quality of the rules we've had. Rules
definitely feel more reliable when everything is tested rather than when only some parts are. And there is the benefit
that tests showcase what the results look like, which can help a new contributor understand the rule.

Data extract is no exception to this logic. Therefore, if a rule extracts data in a test case, then you have to indicate
the expected JSON using [`Review.Test.expectDataExtract`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test#expectDataExtract)
for instance.

The testing API for `elm-review` so far hasn't been very extensible. If you only have local errors, then you can use
[`Review.Test.expectErrors`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test#expectErrors).
If you have global errors, then
[`Review.Test.expectGlobalErrors`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test#expectGlobalErrors). And so on.

But if you had both local and global errors, then you had to use [`expectGlobalAndLocalErrors`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test#expectGlobalAndLocalErrors).
If you had errors for (non-local) modules along with global errors, then you needed to reach for [`expectGlobalAndModuleErrors`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test#expectGlobalAndModuleErrors).

With data extracts adding to the list of things to test, the API for testing rules started smelling like a combinatorial
explosion. So there is a more flexible API for expecting multiple things, which is enabled by the introduction of
[`Review.Test.expect`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test#expect). Follow the
link to see what that looks like.


## Afterword

I am very curious to see how people end up using this feature and for what purposes. Let me know what you think, I would love the feedback. Anyway, I sure hope you like it!

If you feel like you or your company benefit from my efforts, please consider [sponsoring me](https://github.com/sponsors/jfmengels/)
and/or talking to your company about sponsoring me, I would really appreciate it.
