---
title: Measuring cognitive complexity with elm-review
slug: cognitive-complexity
published: "2021-07-07"
---

I just published a new [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/) package and
rule: [`elm-review-cognitive-complexity`](https://package.elm-lang.org/packages/jfmengels/elm-review-cognitive-complexity/latest/), which lets you know about functions that are too complex.

## Cyclomatic complexity

Before introducing **cognitive** complexity, let's introduce **cyclomatic** complexity first. If you've seen rules that report too high complexity, chances are it was "cyclomatic complexity".

It computes complexity in a way that increments the count for every
branch that the code needs to go through. It's a decent measure for computing how many tests you need to have full
coverage, but it's not a great metric to know how or when to split up a function into several functions.

For instance, it increments the complexity by 1 for every branch of a case expression (among others).

```elm
toInteger : Thing -> Int
toInteger thing =
    case thing of
        A ->  -- +1
            1
        B ->  -- +1
            2
        C ->  -- +1
            3
        -- ...
```


The rule is usually paired in a static analysis tool with a threshold, above which the rule reports that the function
needs to be simplified or split. In [ESLint's version](https://eslint.org/docs/rules/complexity) for instance, the threshold
is set at 20 by default. Meaning that if a function has a higher total complexity than 20, the rule would report an error.

In Elm, measuring complexity would not work well because a lot of the `update` functions for instance would be considered
too complex, without a way for us to split them up in any reasonable way, meaning you'd need to resort to a disable
comment ([which I love...](/disable-comments)). You _could_ split the case expression into 2 using default branches, but
that is just so much worse.

Overall I've rarely felt like cyclomatic complexity pushed me towards writing better code. Rather it pushed me towards
disable comments most of the time, so I disabled the rule in my JavaScript projects and never wrote an `elm-review` rule
for it.

## Cognitive complexity

Cognitive complexity, [as designed by SonarSource](https://www.sonarsource.com/resources/white-papers/cognitive-complexity/), takes a different approach
that I found interesting, where it increases complexity by how many linear breaks a function contains.

If you can read the function like a book from top to bottom, the complexity is very low. If the function has a lot of branching,
then the complexity increases. The difference is in branch**ing** versus branch**es**. A case expression will only
increment the complexity by 1, regardless of how many branches it has.

```elm
toInteger : Thing -> Int
toInteger thing =
    case thing of -- +1
        A ->
            1
        B ->
            2
        C ->
            3
        -- ...
```

The total complexity is 1, which I think is fair as it is a very stripped-down function.

Similarly, an if expression increases the
complexity by one. Additional "else if"s also increase complexity, because every else if adds a new condition,
potentially on a new set of variables (compared to a case expression), and every one needs to be processed by our brains.

```elm
-- Total complexity: 3
toInteger : Thing -> Int
toInteger thing =
    if thing == A then      -- +1
        1
    else if thing == B then -- +1
        2
    else if thing == B then -- +1
        3
    else                    -- +0
        4
```

The most interesting part of this metric, is that complexity doesn't increase by 1 every time: **it increases by 1 plus nesting**.
Meaning that if you put an if expression **inside** a case expression, then that if expression will increment the complexity even more.
If you nest branches more and more, then the complexity will increase at a greater rate.

```elm
-- Total complexity: 10
fun cond1 cond2 cond3 cond4 =
    if cond1 then        -- +1
      if cond2 then      -- +2 (including 1 for nesting)
        if cond3 then    -- +3 (including 2 for nesting)
          if cond4 then  -- +4 (including 3 for nesting)
            1
          else
            2
        else
          3
      else
        4
    else
      5
```

Since the complexity increases faster the more you nest things, if you remove one level of nesting, you might reduce the nesting by half or even more. If you add a level of nesting, the opposite is true as well.

But don't get frightened by very high complexity values, since they can potentially be relatively easy to solve. What matters is not how high the complexity is, what matters is that you get it reduced to an acceptable value.


The result in `elm-review` looks like the following:

<anchor id="error-example"/>
```ansi
[38;2;51;187;200m-- ELM-REVIEW ERROR ------------------------------------ src/MyModule.elm:116:1[39m

[38;2;255;0;0mCognitiveComplexity[39m: tooComplexFunction has a cognitive complexity of 22,
higher than the allowed 15

115| tooComplexFunction : Config -> ComplexResult
116| tooComplexFunction config =
     [38;2;255;0;0m^^^^^^^^^^^^^^^^^^[39m
117|     if config.someValue == config.otherValue then

This metric is a heuristic to measure how easy to understand a piece of code is,
primarily through increments for breaks in the linear flow and for nesting those
breaks.

The most common ways to reduce complexity is to extract sections into functions
and to unnest control flow structures. Following is a breakdown of where
complexity was found:

Line 117: +1 for the if expression
Line 118: +2 for the case expression (including 1 for nesting)
Line 123: +3 for the case expression (including 2 for nesting)
Line 128: +4 for the case expression (including 3 for nesting)
Line 129: +1 for the indirect recursive call to someOtherFunction
Line 157: +5 for the if expression (including 4 for nesting)
Line 167: +6 for the case expression (including 5 for nesting)
```

## Reducing complexity through refactoring

The aim of the metric and rule is to push you towards changing your code in a way that makes individual functions easier to grasp.
It's not going to be needed for functions which a low complexity like 3, but rather for functions with a complexity
higher than 15 or another configurable value (we'll cover that in a bit).

The most obvious way to reduce the complexity of this function would be to split the function into several ones, as that
would reduce the increments caused by nesting.

If we take the following function:

```elm
-- Total complexity: 3
toInteger : Thing -> Bool -> Int
toInteger thing condition =
    case thing of -- +1
        A ->
            if condition then -- +2 (including one for nesting)
                0
            else
                1
        B ->
            2
        -- ...
```

then we can split it up like this:

```elm
-- Total complexity: 1
toInteger : Thing -> Bool -> Int
toInteger thing condition =
    case thing of -- +1
        A ->
            valueForCondition condition
        B ->
            2
        -- ...

-- Total complexity: 1
valueForCondition : Bool -> Int
valueForCondition condition =
    if condition then -- +1
        0
    else
        1
```

[Joël Quenneville](https://twitter.com/joelquen) talks about "separating branching code from doing code". He likes to split his functions into functions
that _branch_ (with case and if expressions) from ones that _do_, which I think would help out in most cases where a too
high cognitive complexity is found. He wrote an example of this in [his article about `Maybe`s](https://thoughtbot.com/blog/problem-solving-with-maybe#extracting-functions). 

Another way to reduce the complexity is to collapse the conditions into less conditions.

```elm
-- Total complexity: 3
fun cond1 cond2 =
    if cond1 then        -- +1
      if cond2 then      -- +2
        1
      else
        2
    else
      2

-->

-- Total complexity: 1
fun cond1 cond2 =
    if cond1 && cond2 then -- +1
        1
    else
        2
```

The metric authors' suggestion would be to use `if` and early returns (`if (cond) { return 1; }`) instead of `if/else` when possible,
but that is not a thing in Elm.

There are a number of constructs that increment the complexity and nesting (case expression, if expression), only nesting
(let functions, lambdas), or only complexity (boolean operators like `&&` and `||` and mixing of these).
These are detailed in [the rules's documentation](https://package.elm-lang.org/packages/jfmengels/elm-review-cognitive-complexity/latest/CognitiveComplexity).

## Notes on the design

The metric is designed very close to the original design, the only differences I remember is about not including the
handling of constructs not available in Elm, such as loops, `goto`, etc.

I think that the metric could be altered somewhat with user feedback and as we notice more and more Elm-specific details
that make code harder or easier to grok, though I intend to stay relatively close to the original design.

Note that this is only a single metric, which only works at a function-level, not anything at a higher or lower level of architecture.
You could compute the sum of the functions to compute the complexity of the module, but I'm not sure that makes much sense in Elm.

The rule is not meant to measure the interaction and organisation of individual and complex parts of a codebase, nor is
it about reporting some code styles that could be considered harder to understand than others (like point-free style,
the opinions diverge on this one).

What I mean to say is that this is far from the silver bullet for making all code simpler. You should likely combine it
with others metrics (though there aren't any available as far as I know at the moment...) and gut feeling to find how best
to manage and silo complexity.


## Try it out

So what should you do with this? Well, you could try it out! An easy way to do that is by running the following command
in your Elm project.

```bash
npx elm-review --template jfmengels/elm-review-cognitive-complexity/example --rules CognitiveComplexity
```

The threshold chosen by this configuration is set at 15 by default, but if you add the rule to your configuration, you
would be able to set it to any other value.

I would recommend to enable it in your configuration with a very high threshold to find places in your existing codebase that most need
refactoring, and to make sure no new extremely complex functions appear. As you refactor more and more of your codebase,
you can gradually lower the threshold until you reach a level that you feel happy with. Please let me know if that works
out for you, or if you succeeded through other methods.

I haven't myself tested this extensively on my projects, but the amount of testing I made with high threshold already
reported some functions that I agreed would be in need of splitting up.

**This rule is an experiment.** I don't know if this will be useful or detrimental. I believe this rule to be a lot
more actionable than cyclomatic complexity at least, especially since a solution is often to split a function which Elm
makes very easy.

I haven't yet figured out what the ideal complexity threshold for Elm projects is.
At SonarSource, the default is at 15 for most languages, and 25 for C, C++ & Objective-C where developers seem to have a higher
tolerance for complexity. I don't believe there is a particular need for a high threshold in Elm code, and maybe it should
actually be lower, like 10. Let's try it out and see.

Please give me feedback when you try this rule out!


## Learn more

For a better explained summary of the design and goals of the metric, go read the [white paper](https://www.sonarsource.com/resources/white-papers/cognitive-complexity/).
If you're interested in learning more, [G. Ann Campbell](https://twitter.com/GAnnCampbell) recently recorded a webinar focused on [refactoring through cognitive complexity](https://community.sonarsource.com/t/webinar-refactoring-with-cognitive-complexity/45331) (including video and answers to Q&A).
more. She did several [other talks on the subject](https://www.youtube.com/results?search_query=cognitive+complexity+campbell) if you really want to go in depth, some of them going more into the design of the metric.

I hope you find value in this rule, and I'd like to thank to the team at SonarSource for designing the metric and for not
restricting its use, and more specifically G. Ann Campbell for the different talks she made on the subject.