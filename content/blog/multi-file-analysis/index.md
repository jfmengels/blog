---
title: Multi-file analysis for linters
date: '2023-03-03T08:00:00.000Z'
---


Recently I've been in a few discussions about implementing multi-file analysis in several single-file linters.
I believe that to be an amazing feature and that it is done quite well in [`elm-review`](https://elm-review.com/), so I
wanted to write down how that works for this tool to help others do the same.

Also, I think it's interesting, and I'd like to reduce my project's bus factor.

# Single-file vs multi-file

So what do these terms mean? Single-file analysis in a linter means that a rule looks at files in isolation, whereas multi-file analysis means a rule can analyze multiple files — or entire projects — together and report issues based on what it found in the different files.

For a single-file linter, whenever a linter analyzes a file, it runs some rules and discovers some errors. It then goes on to the next file doing the same thing, completely forgetting about the previous file and whatever it discovered in there (with the exception of the reported errors).

For a multi-file linter, it's the same thing except that rules can remember facts about files that they previously visited.

In `elm-review`, the original and first use-case was to prevent false reports by getting more information, mostly around how imports can hide certain necessary details.

## Elm's import system

In Elm, this is how imports are done:
```elm
import A exposing (..)
-- or
import A exposing (SomeType, someValue)
```

If you do `exposing (SomeType, someValue)`, then the type `SomeType` and the value `someValue` become available in the scope of the entire file.
The `exposing (..)` does the same thing, but imports everything that the module exposes in the file's scope.

The problem with the less explicit `exposing (..)` is that it somehow hides information about what is imported. Say that for some rule, we need to know where `someValue` comes from in the code below:
```elm
module A exposing (main)

import B exposing (..)
import C exposing (..)

main = someValue
```

Is `someValue` imported from `B` or from `C`? We can only tell that by knowing whether to look at the contents of those modules. But with the limitations of single-file analysis, this information is out of reach, and we can only guess this. And if the tool makes the wrong guess, then that may result in a false positive or a false negative.

`elm-review` made the deliberate choice of not supporting disable comments (see [Why you don't trust your linter](https://www.youtube.com/watch?v=XjwJeHRa53A)), meaning it would always have to be correct. And with that limitation, `elm-review` v1, which only supported single-file analysis, **only had 3 released rules** before I felt the crushing weight of this limitation.

Once multi-file analysis got added in v2, that restriction got lifted. Plenty of new rules got released, and now users find this to be the most reliable linter they've ever used. And still no disable comments in sight.
(To be clear, a lot of the reliability of the linter [comes down to the design of the target language](https://www.youtube.com/watch?v=_rzoyBq4hJ0)).


## Use-cases

The rule I find to be the most obvious user of multi-file information is one that reports unused exports: when a file exposes some functions or types but are in practice never used by other files. For `elm-review`, we called this rule [`NoUnused.Exports`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports).

If you can't gather from other modules whether an exposed element is referenced, then you can't ever report it as unused.
I think you can basically use the presence of this rule as a litmus test to know whether a linter supports multi-file analysis or not.

Reporting import cycles — when module `A` imports `B` and `B` imports `A` — is another common one. Import cycles are a bane in a number of programming languages. I remember
getting some of the most difficult behavior to debug in a JavaScript project when there happened to be an import cycle,
and I would have loved a tool to report this issue to me back then. In `elm-review`, this use-case is a bit special as
it is reported not as a rule, but by the tool itself, but more on that a bit later.

In general, it's just about getting necessary information. For instance, there are a number of rules for `elm-review`
that need to know the contents of an imported module, to know the possible variants for a custom type, and similar things.
The [`NoDeprecated`](https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/NoDeprecated) rule for instance takes a look at whether a function's documentation includes a deprecation message,
and needs multi-file information in order to report deprecated functions defined in other files.


## How it works for elm-review

I'll start by explaining single-file analysis, then go on to explain multi-file analysis.

### Single-file analysis

One crucial thing to know about `elm-review` rules is that they are written in Elm, and that has a few different impacts in how it works — both good and bad — but I'm pretty happy with the results.

An important part of writing things in Elm is that everything is immutable and nothing can cause side-effects. In other words, all functions are pure: they take inputs and return a value, and that is all they can do.

In ESLint and other tooling, there is a `context.report({...})` function that you need to call to report errors. But this is done as a "side-effect", it's not the return value of the visitor (the function that analyzes parts of the file).
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
being explicitly given (well unless that data is a global constant, which is not super useful for this purpose). So in
the example above, the visitor **only** has access to a `Node Expression`, and nothing else.
No nodes it visited previously, no global variables in which we sneakily stored some data, nada.

So if we want to gather some data and re-use it elsewhere, we need to do so explicitly. Which is why the API for creating
rules has the concept of a "context". Rule authors define the type of their `Context` and what information that holds and
persists across node visits, and then the framework passes it to visitors and stores a new one.


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

Anyway, this concept of defining and passing around a `Context` and list of errors (which the framework mostly does for you) ends up working quite well in my opinion. This is the way that `elm-review` rules analyze a single-file, but it is not enough for multi-file analysis.

### Multi-file analysis

So how does one file get access to data from other previously-visited modules? Well for the same reasons as before, we can't just access a
global variable containing that data. So once again we have to pass around a context.
Whatever you want to pass from one module to another, you have to store in there.

But because the data that you care about while visiting a file and the data you want to collect from (or send to) other
files usually end up being quite different, we will store data into 2 different contexts: a `ModuleContext` (the
previously explained `Context`, for visiting a single module) and a `ProjectContext` (for the entire project).

In `elm-review`'s terminology, a rule that only looks at single files in isolation is named a "module rule" (we make those easier because they are still quite common) and one that looks at multiple files is named a "project rule" (because `elm-review` looks at entire Elm projects, not only a select number of Elm files).

So what do we do to create a project rule? It's a bit more complicated than for creating a module rule, as we need to define multiple things:
1. The initial project context
2. The visitors that will look at project specific resources (the `elm.json` file, the data from dependencies, the `README` and later on any arbitrary files)
3. The visitors for looking at every module (using the same visitors for module rules)
4. How to create/combine the different contexts (this is the interesting part)

You can read the documentation on how to create a project rule in the [documentation](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#creating-a-project-rule) if you wish to know more about the API (it's a public API so meant to be accessible), but I'll summarize the grand ideas about the contexts, and specify some of the hidden implementation details.

```elm
rule : Rule
rule =
  -- 1. Defining the rule name and the initial project context
  Rule.newProjectRuleSchema "NoUnusedModules" initialProjectContext
    -- 2. visitor for project resources
    |> Rule.withElmJsonProjectVisitor elmJsonVisitor
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

For multi-file visits, the main idea is that every time a module was analyzed, we create a `ProjectContext` from the
`ModuleContext` we got out at the end of the module's analysis using the provided `fromModuleToProject` context, and we
then discard the `ModuleContext`.

So that's how we "export" data from a module to make it accessible to others, but how does they access it?
Well, when we visit a module, we need to create an initial `ModuleContext`, which will be used for the file's analysis.
So we create that using the provided `fromProjectToModule` function, which takes the `ProjectContext` from other modules as
an argument (The function's type is `ProjectContext -> ModuleContext`).

We could have decided to give *all* of the project contexts (`List ProjectContext -> ModuleContext`), but that is not super practical to use. Instead we're only giving a single one which is the result of folding (or "reducing") all of the `ProjectContext`s into one. This folding is done by iteratively calling the provided `foldProjectContexts` function, which is a function that takes 2 `ProjectContext` and returns a combined one (`ProjectContext -> ProjectContext -> ProjectContext`). I like thinking about this a bit like a map-reduce algorithm.

An important restriction is that modules don't have access to the `ProjectContext`s for all other files, only to the ones for the modules they directly import. Giving access to all the files would result in a chicken and egg situation,
whereas with this restriction everything becomes much easier, but also a lot more predictable. This does however, for
better or worse, mean we in practice have a somewhat restrictive order in which we visit the different modules.

For example, let's say we have these modules A and B:
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

`A` imports `B`, so we first need to analyze `B`. `B` imports `C` and `E`, so we need to analyze them first. Once that is done, we can visit `B`. We take the resulting `ProjectContext` for both `C` and `E`, and we fold them together with the initial `ProjectContext` (in essence `foldProjectContexts contextForA (foldProjectContexts contextForE initialContext)`), which we then use to visit `B`.

For `A`, we'll take the `ProjectContext` for its direct imports only, so `B`, `C` and `D`, but not `E`.

More information on how this works and examples in `elm-review`'s [documentation](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withModuleContext).

TODO Make example of a rule modules? Or find better example. Maybe we have some in our documentation. Or link to there.


### Import cycles (once again)

We want a module to get access to the `ProjectContext` from all of its imports, so we need to analyze those first.
This means that we need to create an import graph of the project to figure out the order in which modules should be visited.

We may be able to parallelize some analysis, but we're definitely going to be more constrained than for
single-file analysis. (Note that in practice `elm-review` doesn't parallelize analysis because of the poor parallelization support in JavaScript/Elm).

One tricky situation that might happen is when there are import cycles. Say we have two modules `A` and `B`. If `A`
imports `B` (directly or indirectly) and `B` also imports `A`, which one should we run first? Say we start with `A`,
should we re-analyze it once `B` is analyzed so that `A` now has the information from `B`?
But what if `A`'s resulting `ProjectContext` is different? Should we re-run `B` again as well?

To avoid this problem, `elm-review` doesn't compute an import graph, but an import tree, which is a graph without cycles,
and make this a core requirement to run the tool. If there are any import cycles in the project, then we report that to
the user and abort any additional work. This is not as harsh a requirement as it may seem, because the Elm compiler
already enforces this anyway.

This system that I've shown works in practice really well. It looks like a handful of API calls to set up, but the idea ends up being quite simple and intuitive after a while (to me at least!).

## Specificities for Elm

Elm as a target language once again has some characteristics which makes this viable, but I'm not certain that this will *necessarily* work for all languages.

Because there are no side-effects in Elm, it is NOT possible for a file's behavior to be affected **in any way** by another module that imports it. Anything in an Elm file is affected only by the code in that file and by the different functions that it imports. And that is a very desirable property for analysis.

For instance, in JavaScript, you can have a function in module `A` like this:
```js
function sortByRank(array: Array<Thing>) {
	return array.sort((a, b) => a.rank - b.rank);
}
```

Then in a different module `B`, someone may have written this code which overrides the behavior of `A`'s `sortByRank` function.

```js
// Override sort() to return the unchanged array.
Array.prototype.sort = function dontReallySort(array) {
	return array;
};
```

Some rule may try to understand what's happening in `A` and record the fact that `sortByRank` sorts arrays.
If the rule has not yet seen the contents of `B`, then it might not know that `array.sort()` doesn't sort things and therefore make incorrect conclusions which lead to false reports (false positives and false negatives).

Overriding prototypes is obviously bad (nowadays, not considered that way in the early days), but this applies also to altering global variables, redefining methods through child classes, and other chaotic features of dynamic languages.

I actually think that linters for languages similar to JavaScript and Python — where code is very dynamic and hard to analyze, where you can override behavior and have these "spooky actions at a distance" — are often single-file-based because what's the point of having it be multi-file if you can't be sure of anything anyway?

Also, these odd behaviors are (more) likely to happen in dependencies, which rarely tend to be analyzed by linters anyway, meaning they wouldn't be discovered even with multi-file analysis.

I've encountered a bit of pushback in discussions about adding multi-file analysis in some linters, because it's unclear what useful and reliable information could be retrieved with this. And it's true that for more dynamic languages, you might not get much *reliable* information.

In Elm however, simply because of the fact that you can't mutate anything, you don't have these effects and these problems. This is part of the things I talk about in [Static Analysis Tools Love Pure FP](https://www.youtube.com/watch?v=_rzoyBq4hJ0). Therefore, more complex analysis becomes possible and starts being interesting, which is why I want language designers to take this analysability aspect into account when making their language.

So, does the approach I described for `elm-review` work for other languages? To some extent yes, simply because of the fact that you *can* do multi-file analysis. But if you wanted to avoid any premature conclusions about "brittle" parts, you would need to analyze all files before reporting anything, meaning that this somewhat complex architecture might not be ideal.

That said, I think that for most rules this architecture would probably work well.

## Caching

`elm-review` has a cache both on the file-system and in memory (for its watch mode and for its fix mode). Whenever we notice that file `A` has changed, we reanalyze it.
The result will be either of two things: the resulting `ProjectContext` will be the same as before, or it will be different.

If it has changed, then we need to reanalyze the modules that directly import `A`, and so on. If it hasn't changed, then we can safely skip reanalyzing those same files: Since the analysis is written as a pure function, given the same inputs, the same outputs are guaranteed.

One benefit of splitting the `ModuleContext` and `ProjectContext` is that it's less likely that the `ProjectContext`
will change given minute changes to the file. A `ModuleContext` will often need to know about the position of some expression,
which is information that is very likely to change. If we can avoid it, then these which will not be stored in the `ProjectContext`.
So if we only had a single type of context, then we would invalidate our cache a lot more.

But as you may notice, the `ProjectContext` for imported modules is now part of the "cache key" for the file.
With single-file analysis, you can use use the cached results as long as you know that the file is unchanged, and you can
potentially even skip loading the file's contents into memory.

With multi-file analysis (at least the way I presented it), this is not enough: if an imported module (direct or indirect)
is changed, then it can change the results for any other module.

## Need to analyze everything

An additional problem with multi-file analysis, is that it becomes important to analyze all files, even the ones whose errors are ignored.

Take for instance the rule for reporting unused exports. Say `A` exposes a function `b`. If this function is **only** used in a file that is ignored, then suddenly `A.b` starts getting reported as unused, which is false. Therefore, you need to analyze even ignored files.

But that also means you need to include all files. In Elm, we know at compilation time which files are included in the project because that's written down in the `elm.json` file. So in practice, the recommended way to run the tool is without specifying any files to analyze, letting the tool look at whatever `elm.json` lists. Specifying some files (but not all) can lead to false reports.

But for languages or ecosystems where there is no central file that dictates what is part of the project and what isn't, this becomes harder to figure out, or requires the linter to request more configuration from the user.

# Summary

`elm-review`'s multi-file analysis works great for its target language. There are some specificities that may make it appropriate only for Elm, but maybe it's the best system for other languages anyway. I'd be curious to know how other linters do it.

`elm-review`'s design has been very guided by the restrictions of the Elm language, and I think that the result is fairly nice and very predictable, and helps avoid problems around flaky results that might be hard to track down for other linters.

Different designs might work better for other tools. I hope I explained most of the problems and unexpected implications
that linter authors will likely encounter when implementing this feature. It does make linters a lot more powerful and reliable, so in my opinion it is very much worth it.