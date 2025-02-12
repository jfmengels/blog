---
title: Implementing multi-file analysis for linters
content/blog/multi-file-analysis/index.md
published: "2023-03-24"
---

Recently I've been in a few discussions about adding support for multi-file analysis in several single-file linters.
I believe that to be an amazing feature and that it is done quite well in [`elm-review`](https://elm-review.com/), so I
wanted to write down how it works to help other tools do the same. Hopefully it will be interesting for non-tooling authors as well!


# Single-file vs multi-file

First, what do I mean with these terms?

Single-file analysis in a linter means that a rule looks at files in isolation, whereas multi-file analysis means a rule
can analyze multiple files together — up to entire projects — and report issues based on what it found in the different
files.

For a single-file linter, whenever a rule analyzes a file, it may discover some errors. It then goes on to the next file
doing the same thing, completely forgetting about the contents of the previous file and whatever insights it discovered
in there, only keeping the reported errors.

For a multi-file linter, it's the same thing except that rules can remember facts about files that they previously visited.

In `elm-review`, the original and first use-case was to prevent false reports by getting more information, mostly around how imports can hide certain necessary details.

## Example of Elm's import system

In Elm, this is how imports are done:
```elm
import A exposing (..)
-- or
import A exposing (SomeType, someValue)
```

If you do `exposing (SomeType, someValue)`, then the type `SomeType` and the value `someValue` become available in the scope of the entire file.
`exposing (..)` does the same thing, but that imports everything that the module exposes in the file's scope.

The problem with the less explicit `exposing (..)` is that it somehow hides information about what is imported. Say that some rule needs to know where `someValue` comes from in the code below:
```elm
module A exposing (main)

import B exposing (..)
import C exposing (..)

main = someValue
```

Is `someValue` imported from `B` or from `C`? We can only tell that by looking at the contents of those modules.
But with the limitations of single-file analysis, this information is out of reach, and we can only guess this.
And if the guess is wrong, then that may result in a false positive or a false negative.

`elm-review` made the deliberate choice of not supporting disable comments (see [Why you don't trust your linter](https://www.youtube.com/watch?v=XjwJeHRa53A)),
meaning it should always be correct (otherwise the user's experience is terrible). And with that limitation, `elm-review` v1, which only supported single-file analysis, **only had 3 released rules** before I felt the crushing weight of this limitation.

Once multi-file analysis [was added in v2](/elm-review-v2/), that restriction got lifted. Plenty of new rules got released, and now users find this to be the most reliable linter they've ever used. And still no disable comments in sight.
(To be fair, a lot of the reliability of the linter [comes down to the design of the target language](https://www.youtube.com/watch?v=_rzoyBq4hJ0)).

## Use-cases

The rule I find to be the most obvious user of multi-file information is one that reports unused exports: when a file exposes functions or types that are never referenced in other files. Similarly, you can report unused modules, which are imported by no other modules and don't contain a `main` entrypoint.
For `elm-review`, both concerns are handled by the [`NoUnused.Exports`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports) rule.

If you can't gather from other modules whether an exposed element is referenced, then you can't ever report it as unused.

Considering the high value of this rule, I think you can use its absence or presence as a litmus test of whether a linter
supports multi-file analysis or not.

Reporting import cycles (or "cyclic imports") — when module `A` imports `B` and `B` imports `A` — is another common one. Import cycles are a bane in a number of programming languages. I remember
getting some of the most difficult behavior to debug in a JavaScript project because of this problem,
and I would have loved a tool to report this issue to me back then.

In `elm-review`, this use-case is a bit special as it is reported by the tool itself, and not by a particular rule, but more on that a bit later.

In general, multi-file analysis just about getting necessary information. There are a number of rules for `elm-review`
that need to know the contents of an imported module, to know the possible variants for a custom type, and similar things.
The [`NoDeprecated`](https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoDeprecated) rule for instance looks at whether a function's documentation includes a deprecation message,
and needs multi-file information in order to report references to it in other files.

We love being able to rename things all over our codebase through our editors. But if our editor is not doing multi-file analysis,
then renaming an exported function will result in a behavior change (a compiler error in the best case, a crash in the worst).
If we have multi-file analysis, then we can do this though. Some IDEs are already doing this correctly, and we should be jealous.

## How it works for elm-review

I'll start by explaining how single-file analysis works, and then I'll explain multi-file analysis.

### Single-file analysis

One crucial thing to know about `elm-review` rules is that they are written in Elm, and that has a few different impacts in how it works — both good and bad — but I'm pretty happy with the results.

An important part of writing code in Elm is that everything is immutable and nothing can cause side effects. In other words, all functions are pure: they take inputs and return a value, and that is all they can do.

In ESLint and other tooling, there is a `context.report({...})` function that you need to call to report errors. This is done as a "side effect", it's not the return value of the visitor (the function that analyzes parts of the file).
In Elm, that would not be possible, so instead every visitor needs to explicitly return the list of errors they want to report.

```elm
-- simplified API
rule : Rule
rule =
  Rule.createSingleFileRule "NoDivisionByZero"
    |> Rule.withExpressionVisitor expressionVisitor

expressionVisitor : Node Expression -> List Error
expressionVisitor node =
  case Node.value node of
    Expression.BinaryExpression "/" left (Integer 0) ->
      [ Rule.error "Found division by 0" (Node.range node) ]

    _ ->
      []
```

Given that Elm functions are pure, that also means that it's not possible for a function to access data that it is not
being explicitly given (well unless that data is a global constant, which is not super useful for this purpose).

So in the example above, the visitor **only** has access to a `Node Expression`, and nothing else.
No AST nodes it visited previously, no global variables in which we sneakily stored some data, nada.

So if we want to gather some data and use it elsewhere, we need to do so explicitly. Which is why the API for creating
rules has the concept of a "context". Rule authors define a `Context` type and the information it holds and
persists across node visits, and then the framework passes it to visitors and updates it after each node.


```elm
-- still simplified API
rule : Rule
rule =
  Rule.createSingleFileRule
    { ruleName = "RuleName"
	, initialContext = { timesWeFoundADivisionByZero = 0 }
	}
	expressionVisitor

type alias Context =
  { timesWeFoundADivisionByZero : Int
  }

expressionVisitor : Node Expression -> Context -> ( List Error, Context )
expressionVisitor node context =
  case Node.value node of
    Expression.BinaryExpression "/" left right ->
	  case Node.value right of
	    Integer 0 ->
	      let
	        newCount = context.timesWeFoundADivisionByZero + 1
	      in
		  ( [ Rule.error
		        ("Found division by 0 for the " ++ String.fromInt newCount ++ "th time")
		        (Node.range node)
		    ]
		  , { context | timesWeFoundADivisionByZero = newCount }
		  )

		_ ->
		  ( [], context )

    _ ->
      ( [], context )
```

I'm sure that if you're used to reporting errors through side-effects like `context.report()`, this sounds tedious and annoying, but it does have a few nice properties for maintaining rules, similar to the benefits Elm has for writing applications.

Anyway, this concept of defining and passing around a `Context` and list of errors (which the framework mostly does for you)
ends up working quite well in my opinion. This is the way that `elm-review` rules analyze a single-file, but it is not enough for multi-file analysis.

### Multi-file analysis

So how does one file get access to data from other previously-visited modules? Well for the same reasons as before, we can't just access a
global variable containing that data. So once again we have to pass around a context.
Whatever data you want to pass from one module to another, you have to store in there.

But because the data that you care about while visiting a file and the data you want to collect from (or send to) other
files usually end up being quite different, we will separate them it into two different contexts: a `ModuleContext` (the
previously explained `Context`, for visiting a single module) and a `ProjectContext` (for the entire project).

In `elm-review`'s terminology, a rule that only looks at single files in isolation is named a "module rule" (we make those easier because they are still quite common) and one that looks at multiple files is named a "project rule" (because `elm-review` looks at entire Elm projects, not only a select number of Elm files).

So what do we do to create a project rule? It's a bit more complicated than for creating a module rule, as we need to define multiple things:
1. The initial project context
2. The visitors for project specific resources (the `elm.json` file, the data from dependencies, the `README` and later on any arbitrary files)
3. The visitor for Elm modules (using the same API as for module rules)
4. How to create/combine the different contexts (this is the interesting part)

You can read the [documentation](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#creating-a-project-rule)
on how to create a project rule if you wish to know more (it's a public API, so it's meant to be accessible),
but I'll summarize the grand ideas about the contexts, and specify some hidden implementation details.

```elm
rule : Rule
rule =
  -- 1. Defining the rule name and the initial project context
  Rule.newProjectRuleSchema "NoUnusedModules" initialProjectContext
    -- 2. visitor for project resources
    |> Rule.withElmJsonProjectVisitor elmJsonVisitor
    |> Rule.withReadmeVisitor readmeVisitor
    -- 3. visitor for individual modules
    |> Rule.withModuleVisitor moduleVisitor
    -- 4.How to create/combine the project and module contexts
    |> Rule.withModuleContext
      { fromProjectToModule = fromProjectToModule
      , fromModuleToProject = fromModuleToProject
      , foldProjectContexts = foldProjectContexts
      }
    |> Rule.fromProjectRuleSchema
```

For multi-file visits, the main idea is that every time a module is analyzed, we create a `ProjectContext` from the
`ModuleContext` we got out at the end of the module's analysis, through the provided `fromModuleToProject` function, and we
then discard the `ModuleContext`.

```elm
fromModuleToProject : ModuleContext -> ProjectContext
fromModuleToProject moduleContext =
    { deprecatedFunctions = moduleContext.localDeprecatedFunctions
    }
```

So that's how we "export" data from a module to make it accessible to others, but how do we "import" it?

Well, when we visit a module, we need to create an initial `ModuleContext`, which will be used for the file's analysis.

So what we do is we create that `ModuleContext` using the provided `fromProjectToModule` function, which takes the
`ProjectContext` from other modules as an argument.

```elm
fromProjectToModule : ProjectContext -> ModuleContext
fromProjectToModule moduleContext =
    { localDeprecatedFunctions = []
    , importedDeprecatedFunctions = moduleContext.deprecatedFunctions
    }
```

We could have decided to give all of the project contexts (a list of `ProjectContext`), but that would not
be very practical to use. Instead, we're only giving a single one which is the result of folding (or "reducing") all of the
`ProjectContext`s into one.

This folding is done by iteratively calling the provided `foldProjectContexts` function, which takes two
`ProjectContext`s and returns a combined one.

```elm
foldProjectContexts : ProjectContext -> ProjectContext -> ProjectContext
foldProjectContexts newContext previousContext =
    { deprecatedFunctions =
        List.concat newContext.deprecatedFunctions previousContext.deprecatedFunctions
    }
```

An important restriction is that modules don't have access to the `ProjectContext`s of all other files (or rather the
combination of those), but only to the ones corresponding to the modules they directly import.

Giving access to all the files would result in a chicken and egg situation, whereas with this restriction everything
becomes much easier, but also a lot more predictable. This does however, for better or worse, mean we in practice have a
somewhat restrictive order in which need we visit the different modules.

For example, let's say we have two modules `A` and `B`:
```elm
module A exposing (..)
import B
import C
import D

-- and

module B exposing (..)
import C
import E
```

`A` imports `B`, so we first need to analyze `B`. `B` imports `C` and `E`, so we need to analyze those first. Once that
is done, we can visit `B`. We take the resulting `ProjectContext`s for both `C` and `E`, and we fold them together with the initial `ProjectContext` (in essence `foldProjectContexts contextForA (foldProjectContexts contextForE initialContext)`), which we then use to visit `B`.

For `A`, we'll take the `ProjectContext` for its direct imports only, so `B`, `C` and `D`, but not `E`.

This system works in practice really well. It looks like a handful of API calls to set up, but the idea ends up being quite simple and intuitive after a while (to me at least!), maybe because it resembles a map-reduce algorithm.
More information on how this works and examples in `elm-review`'s [documentation](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withModuleContext).


### Import cycles (once more)

We want a module to get access to the `ProjectContext` corresponding to all of its imports, so we need to analyze those first.
This means that we need to create an import graph of the project to figure out the order in which modules should be visited.

We may be able to parallelize some analysis, but we're definitely going to be more constrained than for
single-file analysis. (Note that in practice `elm-review` doesn't parallelize analysis because of the poor parallelization support in JavaScript/Elm).

One tricky situation that might happen is when there are import cycles. Say we have two modules `A` and `B`. If `A`
imports `B` (directly or indirectly) and `B` also imports `A`, which one should we run first? Say we start with `A`,
should we re-analyze it once `B` is analyzed so that `A` now has the information from `B`?
But what if `A`'s resulting `ProjectContext` ends up different from the first analysis? Should we re-run `B` again as well?

To avoid this problem, `elm-review` doesn't compute an import graph, but an import tree, which is a graph without cycles,
and makes not having import cycles in the project to analyze this a core requirement to run the tool. If there are any
import cycles, then we report that to the user and abort any additional work. This is not as harsh a requirement as it
may seem, because the Elm compiler enforces this already.


### Not all modules need information from other modules

`elm-review` rules have a special visitor/hook, which we named ["final module evaluation"](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withFinalModuleEvaluation) to evaluate errors once the entire AST of a file has been visited.
This is very useful for instance to report [unused variables](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Variables), because you need to have gone through the entire file to be sure that a variable is never referenced anywhere. The hook is a function that takes the `ModuleContext` and returns a list of errors.

For project rules, there is a similar ["final project evaluation"](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withFinalProjectEvaluation) hook for when the entire project has been analyzed, which again is necessary for rules like [`NoUnused.Exports`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports), because you need to have seen the entire project to be sure that an exported element is never referenced in other modules. The hook is a function that takes the `ProjectContext` that is the result of the folding *all* project contexts, and returns a list of errors.

Some project rules won't actually require data from other modules, but use this final project evaluation hook, others will not need that final hook, and some will use both. When the rule doesn't need data from other modules, then the rule author can toggle on/off folding project contexts to initialize the module context, which reduces the amount of work done under the hood and in theory enables modules to be analyzed in parallel.  


### Access to project files

`elm-review` gives access to project files that are not Elm modules. For instance, there is a visitor to look at
the `elm.json` file, one to see the exposed API of all the project's dependencies (which is summarized in a
`docs.json` file), as well as one for the project's README. In the future, we'll likely give access to arbitrary files
that the rule wishes to access (ex: CSS files, `CHANGELOG.md`, ...).

My experience so far has been that the more information you make available, the more accurate the rules can be and the
more possibilities open up for them.

For instance, we now [have rules](https://package.elm-lang.org/packages/jfmengels/elm-review-documentation/latest/) that determine whether there are dead links in the project's documentation and README, and also that (auto-)update links to always include the version of the project that is found in the `elm.json` file.

These "project files" are an important part of a project, and I feel they're too often ignored by other linters. In `elm-review`, these files can be read by both module and project rules.

Project rules can also report errors targeting (and auto-fixing) those files, which is useful for reporting unused
dependencies defined in the `elm.json` file for instance.

For a project rule, the order that these project files and project modules are visited in is pre-determined: first the `elm.json`, then the dependencies, then the README, then each module (in "parallel" or in order of imports), then the finale project evaluation.

## Drawbacks of the approach

### It works, but for Elm

Elm as a target language has some characteristics which makes the approach I've described viable, but I'm not certain
that this will *necessarily* work for all languages.

Because there are no side-effects in Elm, it is **not possible** for a file's behavior to be affected **in any way** by another module that imports it. Anything in an Elm file is affected only by the code in that file and by the different functions that it imports. And that is a very desirable property for analysis.

For instance, in JavaScript, you can have a function in module `A` like this:
```js
function sortByRank(array: Array<Thing>) {
	return array.sort((a, b) => a.rank - b.rank);
}
```

Then in a different module `B`, someone may have written this code, which will impact the behavior of `A`'s `sortByRank` function.

```js
// Override sort() to return the unchanged array.
Array.prototype.sort = function dontReallySort(array) {
	return array;
};
```

A rule may try to understand what's happening in `A` and record the fact that `sortByRank` returns sorted arrays.

If the rule has not yet seen the contents of `B`, then it will not know that `array.sort()` doesn't sort things, and it may therefore make incorrect conclusions, leading to false reports (false positives and/or false negatives).

Overriding prototypes is obviously bad (nowadays, not considered that way in the early days), but this also applies to altering global variables, redefining methods through child classes, and other "chaotic" features of dynamic languages.

Also, these odd behaviors are (more) likely to happen in dependencies, which tend to not be analyzed by linters anyway (they will be in `elm-review`, one day...), meaning they wouldn't be discovered even with multi-file analysis.

I actually think that linters for languages similar to JavaScript and Python — where code is very dynamic and hard to analyze, where you can override behavior and have these "spooky actions at a distance" — are often single-file-based because "what's the point of having it be multi-file if you can't be sure of anything anyway?"

I've encountered a bit of pushback in discussions about adding multi-file analysis in some linters, because it's unclear what useful and reliable information could be retrieved with this. And it's true that for more dynamic languages, you might not get much *reliable* information.

In Elm however, simply because you can't mutate anything, you don't have these effects and these problems.
Therefore, more complex analysis becomes possible and starts being interesting, which is why I want language designers to take this analyzability aspect into account when making their language.
More on that in [Static Analysis Tools Love Pure FP](https://www.youtube.com/watch?v=_rzoyBq4hJ0).


## No magic access to data

Another problem with my approach, is that you can't just request data out of thin air.

For instance, you (as the rule author) can’t just encounter a reference to a function and ask some tool to get details about the function such as its type,
which is what some tools like [typescript-eslint](https://typescript-eslint.io/) are doing (by querying the TypeScript compiler) as far as I can tell.

Instead, you have to collect that information first, and then you can query data you stored in the context.
The linter can help provide that information if it's commonly requested by rules so that it doesn't feel painful, but
ultimately under the hood it will work in the same manner as if you had collected it yourself.

A case where this is ostensibly painful is if you want to make a graph of all the references the `main` function directly
or indirectly makes, because you will have to do things in a pretty backwards way: for each function of the
project collect all the references that they make, and then once you've found the main function, combine all this
information to make the graph (disregarding the data of the functions not referenced).

When doing this with an additional service — like `typescript-eslint` (probably, not entirely sure) or `ts-morph` would —
you would start from `main`, and then for each reference it makes, you ask the TypeScript compiler for the implementation
of the function, and you'd do so recursively. That's super easy and efficient.

Well, efficient code-wise at least. Under the hood, I'm guessing that the TypeScript compiler does things somewhat like `elm-review`,
though I don't know if it does the required analysis on demand for each request (and how well it caches/memoizes
the analysis), or whether it pre-analyzes everything ahead of time like `elm-review` would.

In the early days of multi-file linting in `elm-review`, for this kind of use-case, I wanted to support visiting modules in the opposite order of
modules (importing module first, imported module last) for the rules that requested it, which would help with the
previous example (store the name of referenced functions, and skip functions whose name is not in there). But now I think
that that would make the analysis process not performant because rules will usually still need data from the imported modules.


## Caching

Multi-file analysis has a surprising effect on caching. 

`elm-review` has a cache both on the file-system and in memory (for its watch mode and for its fix mode). Whenever we
notice that file `A` has changed, we reanalyze it. The result will be either of two things: the resulting `ProjectContext`
will be the same as before, or it will be different.

If it has changed, then for this given rule we need to reanalyze the modules that directly import `A`, with a potential
ripple effect. If it hasn't changed, then we can safely skip reanalyzing those same files: Since the analysis is written
as a pure function, given the same inputs, the same outputs are guaranteed.

We can be sure that no rules, even those made by users, sneakily stored things in a global variable or called a
third-party tool whose answer might change from one analysis to another. If that happened, then we could potentially
reanalyze the project and end up with different results even when the project hasn't changed.

One benefit of splitting the `ModuleContext` and `ProjectContext` is that it's less likely that the `ProjectContext`
will change given minute changes to the file. A `ModuleContext` will often need to know about the position of some expression,
which is information that is very likely to change. If we can avoid it, then these will not be stored in the `ProjectContext`.
So if we only had a single type of context, then we would invalidate our cache a lot more.

But as you may have realized, the `ProjectContext` for imported modules is now part of the "cache key" for the file,
which has a terrible consequence.

With single-file analysis, you can use the cached results for a given file as long as you know that the file is unchanged, and you can
potentially even skip loading the file's contents into memory.

But with multi-file analysis (at least the way I presented it) this doesn't hold anymore. If a module has changed, then
it can potentially change the results for any other module that imports it. This makes caching a lot harder and
inefficient, especially if we talk about caching on the file system. 

## Need to analyze everything

An additional problem with multi-file analysis is that it becomes important to analyze all files, even the ones whose errors we ignore.

Take for instance the rule for reporting unused exports. Say `A` exposes a function `b`. If this function is **only**
used in a file that is ignored by the user and this file's analysis is skipped, then `A.b` will incorrectly be reported
as unused.

Therefore, you need to analyze even ignored files. You get the same problems if you try to only analyze "dirty" files
(not committed in a versioning system like Git).

In fact, you will need to include all files from the project. In Elm, we know at compilation time which files are
included in the project because that info is written down in the `elm.json` file. So in practice, the recommended way to
run the tool is without specifying any files to analyze, letting the tool look at whatever `elm.json` lists (`elm-review` instead of `elm-review src/ tests/ lib/`).
Limiting the analysis to only some files can lead to false reports.

But for languages or ecosystems where there is no central file that dictates what is part of the project and what isn't,
this becomes harder to figure out, or requires the linter to request more configuration from the user. If we take
JavaScript projects for instance, where you can find some JS code inside of HTML files or even reference functions that
are not included in the project, things become quite tricky.

The opposite problem is also true. If you aim to analyze *more* than a project — say a "monorepo" — then some rules can
report things differently than what you would like it to (without being incorrect), or you need to find ways to combine
the `elm.json` files for different sub-projects. I have not found an entirely satisfactory solution to this yet.

# Summary

`elm-review`'s design has been very guided by the restrictions of the Elm language, and I think that the result is fairly
nice and very predictable, and helps avoid problems around flaky results that can be hard to track down for other linters.

The multi-file analysis works great for this target language. There are some specificities that may make it
appropriate only for Elm, or comparatively make it work especially well for Elm, but I don't honestly see a better way.

Different designs might work better for other tools, and tools that are not as general-purpose as `elm-review` might
find smart and efficient tricks that work better for their use-case. I'd be curious to learn how other linters do it.

I hope I explained most of the problems and unexpected implications that linter authors will likely encounter when
implementing this feature. These are not easy to solve especially with performance in mind.

Multi-file analysis does however make linters a lot more powerful and reliable, so I really hope it is something that
linter authors will consider implementing.