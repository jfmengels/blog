---
title: A tale of failing to design rule boundaries - Data-last functions
date: '2023-09-18T11:00:00.000Z'
---

In this blog, I usually talk about the things I release and that I believe can be valuable to people. This time, I'm going to talk about a failure: where I tried to make an `elm-review` rule and I could not design it in a satisfactory way.

In this, we're going to talk about finding the boundaries of a rule, and why I didn't come up with a good solution.

## The problem

In Elm, a common pattern for functions is to have the "data" argument be the last argument. Doing so makes it easy to compose code. For example, given the following functions:

```elm  
type Bicycle = Bicycle { {- some fields -} }

newBicycle : Bicycle

withNumberOfGears : Int -> Bicycle -> Bicycle

withTire : Tire -> Bicycle -> Bicycle

withDutchBicycleLock : Bicycle -> Bicycle
```  

because the data that is being altered/modified is the last one (`Bicycle`), we can easily compose these functions using `|>`:

```elm  
myBicycle : Bicycle
myBicycle =
    newBicycle
	    |> withNumberOfGears 7
	    |> withTire mountainBikeTire
	    |> withDutchBicycleLock
```  

or using `>>` :

```elm  
turnIntoMountainBike =
    withNumberOfGears 7
    >> withTire mountainBikeTire
	>> withDutchBicycleLock
```  

If instead, we had `withNumberOfGears : Bicycle -> Int -> Bicycle`, this would not compose as well.

Given this convention, I was thinking we could build a `DataArgumentShouldBeLast` rule to enforce it, and provide guidance to new users of the language that don't know about it yet. So let's explore designing it.

## Finding the boundaries

Whenever I think about a rule, (among other things) I try to find when the rule would apply and would not apply. When I'm unsure, I usually start with a rough idea and then run it against real codebases to see what errors get reported that I don't think are right, and which errors don't get reported that I think should be reported.

Let's look at some random code first:

```elm
someFunction : Int -> String -> List X -> Y -> Z
```

Here, `someFunction` takes 4 arguments of type `Int`, `String`, `List X` and `Y`, and returns something of type `Z`. Which of these 4 arguments should be considered to be a data argument? Well... err... that's hard to tell. I'd even go as far to say it's impossible (accurately at least).

Actually, even for a human sometimes it can be hard to tell which argument is the main data when 2 or more arguments carry a lot of significance.

So let's reduce the boundaries of the rule. In case it helps visualize things, in my mind I sometimes picture a map and redraw the borders of the rule.

A pretty common thing in Elm code is to have a function that takes a type as an argument and returns that same type. Like `withNumberOfGears` from earlier.

```elm
withNumberOfGears : Int -> Bicycle -> Bicycle
```

Here we know what the main type is: it's `Bicycle`. So, let's draw the boundaries of the rule to only report about functions where the return type can be found in the arguments as well (but not as the last argument). So while `withNumberOfGears` above would be okay, we would report the version below:

```elm
withNumberOfGears : Bicycle -> Int -> Bicycle
```

We can write a rule that starts doing just this, and then try to grow or shrink the boundaries as needed. We tend to do this in no particular order (it depends on what we uncover), though for this article I'll regroup them and start with the growing part.

## Growing the boundaries

### Supporting type variables

At this point, we only support simple types where an argument is the same as a return type. That means that if types have type variables (is "generic"), then we won't report them.

A common operation we find on types is `map`. If we find one that looks like the following:

```elm
-- given
type X x
	= X x

map : X a -> (a -> b) -> X b
```

then we'll squint a bit, because it looks odd. The more common pattern is where the data is last:

```elm
map : (a -> b) -> X a -> X b
```

We can change the boundaries to support this as well, by ignoring the type variables.

There are definitely valid use-cases like `map`. But it's possible that this will create problems, for instance if there is a function like below where one argument looks like the main argument and somehow is not the main type. We might need to shrink the boundaries again to not report this.

```elm
someFunction : X a -> Y -> X b
```

### Support containers for the data types

One example I like to use for the example is the typical `update` function:

```elm
update : Msg -> Model -> Model
```

This function is so common for Elm developers that if you were to change the order of these arguments it would look weird.

but there's another typical version of `update` function which returns a tuple:

```elm
update : Msg -> Model -> ( Model, Cmd Msg )
```

Again, very idiomatic. But what if we found

```elm
update : Model -> Msg -> ( Model, Cmd Msg )
```

Well, we would probably want to report this. There's no reason to have the rule cover the first situation but not the second one.

And what if the function returned a record? Or what if it returned a type alias `type alias Return = ( Model, Cmd Msg )`?

I guess it makes sense to support all of these situations too, which would require us to report when an argument is the same as the return type, or when it's *contained* somewhere in the return type.

That makes the heuristic of whether to report an error or not more complicated, and potentially opens up for a new batch of false positives. I have not delved into supporting this use-case, but this is something we could have looked into at some point.

## Shrinking the boundaries

### Encountering core types

So, what happens if we run this rule on a codebase? Well, we might get errors reported for functions like this:

```elm
fn : String -> Maybe Int -> String
```

I don't know what the function here does, but also, I'm not sure that the `String` argument is the main data type. `String`, `Maybe` and `Int` are all core/primitive types, and each one could be the main data, just like they could be something else, making it really hard to know whether the argument order should be changed or not.

Because this is so prone to false positives, I'm thinking we should avoid reporting this case. But how do we exclude it and similar situations?

Well, since `String` is a core data-type, we could say we ignore any function that returns a core type. But is doing so for a core type going to be enough? Can't I have the same problem for types defined in dependencies? Potentially yes. What about types in the codebase that are aliased to core or package types? Also a potential problem.

At this point, my gut feeling says we should start with really small boundaries, and try to grow them again later if we feel like it. The solution I went with was to only report functions that returned a type defined in the same file. A bit restrictive maybe, but a reasonable start.

So because `withNumberOfGears` returns a `Bicycle` which is defined in the same file, we'll report it, but we won't report things like `fn` above now. Okay, this removes a whole bunch of false positives, so that feels pretty solid.

### The deal-breakers

Unfortunately, I found a few situations where I have not been able to remove the false positives or reach satisfactory results.

#### Pipeline-optimized functions

I kind of assumed that the main data is always last, but in practice it's complicated. Or at least situational.

One of the main reasons for having the data last is to be able to easily do operations in a pipeline (`data |> someOperation arg |> otherOperation`). But sometimes the pipeline wants something else.

For instance, I found code like the following:

```elm
doSomething : Context -> Context
doSomething context = 
    context.scopes
        |> NonEmpty.cons newScope
        |> updateScope context

updateScope : Context -> NonEmpty Scope -> Context
updateScope context scopes =
    { context | scopes = scopes }
```

Here, `updateScope` clearly has the arguments in the wrong order. But... it does so *purposefully* in order to make it look good in a pipeline.

And this means, that one of our core tenets for the rule (data should be last to enable pipelines) proves that it's a wobblier idea than originally thought.

So how do we avoid reporting this situation? One thing we could do is to look at the usages of a function. If we notice that it's used in a pipeline like above, then we don't report it.

But how far do we look? Do we look at usages in the same file? Do we look at usages in the rest of the codebase?

If it's a function publicly exposed from a package, then that trail ends abruptly, because we won't necessarily have code examples for it. And that's a shame because reporting this in packages before they get published is where I think this rule would have some of the most value.

And the absence of the usage in a pipeline does not prove that it's not meant to be used that way.

### Functions not meant to be in pipelines

The rule also reported functions like the [following one](https://package.elm-lang.org/packages/zwilias/elm-bytes-parser/1.0.0/Bytes-Parser#repeat):

```elm
repeat :
	Parser context error value
	-> Int
	-> Parser context error (List value)
```

or [this one](https://package.elm-lang.org/packages/league/difference-list/2.0.0/DList#intersperse) (and quite a lot of others found in existing Elm packages):

```elm
intersperse : DList a -> List (DList a) -> DList a
```

Looking at their documentation, some of these functions are meant/recommended to be used in a specific way which is not through pipelines. And that should be okay too.

## Abandoning the rule

Functions like in the last section, although not the most common, felt to me like the last straw that broke the camel's back. More and more functions were brought to my attention where we couldn't automatically do the right thing.

We're trying to help make functions easier to use, and that is more situational than I expected. Unfortunately, not everything fits that simple (naive) mold that I was imagining.

Linting rules are always trade-offs. In this case, I believe that enforcing such a rule can lead to some painful degradations to the codebase, in the (maybe) rare cases where the rule is "wrong" but you still want to follow it so it won't bother you anymore. But the value you get out of it is rather small as well, because it's in practice not super important and can be viewed as a code-style issue.

When the rule brings some pain, the value it brings has to outweigh it, which is not the case for this rule. Hence why I don't believe I'll publish it unless I come up with brilliant new ideas.

But that's mostly when enforcing the rule. Using it as an exploratory tool that you can run from time to time is probably okay though. So maybe I'll publish it in that context, or at least keep it accessible. I might change my mind 🤷

### But... disable comments?

Some people might ask:
> "But can't you just use a disable comment?"

`elm-review` doesn't support that out of the box, so the short answer is no.

Longer answer: No, however it is possible to make the rule design their own exceptions, which we can do in multiple ways.

We can detect the presence of a nearby comment with a specific format, which would in practice be re-implementing disable comments for the rule.

Similarly, we could decide to have "special" symbols in the function's documentation such as `@ignore-data-last` to disable a report. In which case we could also ask users to annotate their function with `@data X` to tell us that `X` is the data type for this function, giving us the information we were scouring for so hard.

I don't really like these options though, because they require the user to put in quite a bit of effort. And that's fine when the rule provides a lot of value, but as I said before, that isn't the case here.

### Afterword

Thank you to [@lue](https://github.com/lue-bird) for finding a lot of counter-examples and **ruining this rule**, though probably for the best 😄

This was an interesting exploration, one that I usually need to do for linting rules, but it's rare that I get disappointed in the feasibility of the rule so far down the line.

But hey, sometimes not making a rule is okay.

The code for the rule, in case you're interested, is available in this [pull request](https://github.com/jfmengels/elm-review-code-style/pull/11). Even though it's not published, you can try it out with the following command and see for yourself whether you think some things are okay or not:

```
elm-review --template jfmengels/elm-review-code-style/preview#data-argument-last --rules DataArgumentShouldBeLast
```