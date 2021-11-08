---
title: Lists, and the cost of maintaining order
date: '2021-09-27T12:00:00.000Z'
---

TODO Add link to https://www.youtube.com/watch?v=VYycQTm2HrM

My recent focus has been in benchmarking and improving performance of Elm code, and it has been very enlightening.

Among the things that I realized is how much unnecessary overhead some functions had. I mean, I guess I knew it, but didn't **realize** it as I didn't consider alternatives.
This is not tied only to Elm, other languages also suffer more or less from the same issues.

## 

A lot of functions in `elm/core` aren't as fast as they could be because they try to respect some properties
that may or may not be useful in the context where they are used.

## An example

[`List.map`](https://package.elm-lang.org/packages/elm/core/latest/List#map) for instance, makes sure that the
order of the mapped items is the same as the order of the items in the input list, so that `List.map f [ 1, 2, 3 ]`
equals `[ f 1, f 2, f 3 ]` and not `[ f 3, f 2, f 1 ]`.

Unfortunately, for lists where accessing the first element is super fast but every other operation is less optimal,
maintaining this order has some performance overhead.

I think it's an interesting exercise to write `List.map` yourself while making sure that elements are in order and that
the function is stack-safe (see [my article on recursion](/tail-call-optimization)) without resorting to other functions
like `List.foldr`. Maybe try it out yourself.

But there are a lot of cases when you don't care about the order. In that case, you might want to reach out to a
[faster `List.map` alternative](TODO link) that doesn't aim to preserve the order.


A lot of overhead happen in Elm code through the use of multiple functions. Take the following example:

```elm
keepEvenElementsAndMap_1 : (a -> b) -> List a -> List b
keepEvenElementsAndMap_1 mapper list =
    list
        |> List.indexedMap Tuple.pair
        |> List.filter (\(index, _) -> modBy 2 index == 0)
        |> List.map (\(_, a) -> mapper a)
```

On a high-level, this function maps every element in a list with its index inside the list, filters out the ones with an odd
index, then returns a list with the mapped values using the `mapper` argument.

Now let's break down what it does with more detail by including the internals of these functions. I'm going to be keeping
count (in parens) of the number of times we'll loop over the list.


1. Call `List.indexedMap`

```elm
indexedMap : (Int -> a -> b) -> List a -> List b
indexedMap f xs =
  List.map2 f (List.range 0 (List.length xs - 1)) xs
```

- Internally, `List.length` is called on the list, meaning we loop over it (1)
- Internally, `List.range` is called to create a list with the same length as the list, similar to looping over the list (2)
- Internally, `List.map2` is called on the original list and the list of indexes. It loops over these combined lists to create a JavaScript Array (3) then creates a list from it (4)
- For every element, we call `Tuple.pair` which creates a new value in memory

(PS: There is an [open pull request](https://github.com/elm/core/pull/1027) to make this function a lot more performant
by doing a lot less work)


2. Call `List.filter`

```elm
filter : (a -> Bool) -> List a -> List a
filter isGood list =
  List.foldr (\x xs -> if isGood x then x :: xs else xs) [] list
```

- Internally, `List.foldr` is called on the list, which is a slower alternative to `List.foldl` that loops over the array in an order that will facilitate keeping the order.
It's somewhat similar to doing `List.foldr` then reversing the resulting list, so I'm going to count it as 2 loops over the list (6).
- For every element, we extract the index then compute the predicate


3. Call `List.map`

```elm
map : (a -> b) -> List a -> List b
map f xs =
  List.foldr (\x acc -> (f x) :: acc) [] xs
```

- Same as `List.filter`, this function uses `List.foldr` (8)
- For every element, we extract the value then compute the mapped value

All in all, I count 7-8 loops over the original list. Let's go through an alternative implementation of this function, that uses manual recursion:


```elm
keepEvenElementsAndMap_2 : (a -> b) -> List a -> List b
keepEvenElementsAndMap_2 mapper list =
    keepEvenElementsAndMapHelper mapper list 0 []


keepEvenElementsAndMapHelper : (a -> b) -> List a -> Int -> List b -> List b
keepEvenElementsAndMapHelper mapper list index acc =
    case list of
        [] -> acc
        x :: xs ->
            let
                newAccumulator : List b
                newAccumulator = 
                    if modBy 2 index == 0 then
                        mapper x :: acc
                    else
                        acc
            in
            keepEvenElementsAndMapHelper mapper xs (index + 1) newAccumulator
```

For every single element, we check for the condition.
- If it's `True`, we recurse over the rest of the list.
- If it's `False`, we compute the mapped value and add it at the beginning of the list (which is a very fast operation), the recurse over the rest of the list.
  When the list to recurse over reaches its end, we return the accumulated value (`acc`).

In this implementation, we loop over the original list only a **single** time, meaning there is a lot less unnecessary computation.
We also allocate a lot less memory: no allocations for all the tuples we end up discarding, nor any allocations for all the list that we end up discarding.

We could write the same thing using `List.foldl`, which would be almost as performant (but not quite, that's a topic for a different post).

The recursive implementation is also tail-call recursive, meaning that it gets compiled to a JavaScript `while` loop,
and not a bunch of function calls, making it quite performant.

In general the recursive implementation is the most verbose, brittle and maybe complicated-looking, but also the most performant
because it adds the least overhead (don't forget to benchmark though).
It is also the most versatile, as you can choose to stop early ([to avoid lots of unnecessary computations](https://github.com/elm-community/result-extra/pull/29)) or even to explore more elements during the traversal (for tree-like data structures for instance).

TODO A common advice to improve performance is to avoid doing unnecessary work. Preserving order is one of those pieces of work that could potentially be stripped.

TODO Talk about the benefits of having an accumulator.

## Keeping the order

If you have a keen eye or some experience with recursion/fold, then you'll notice there is one flaw in my recursive
implementation: the order of elements in the result is not the same as in my first implementation.

```elm
keepEvenElementsAndMap_1 String.fromInt [ 1, 2, 3, 4 ]
--> [ "1", "3" ]

keepEvenElementsAndMap_2 String.fromInt [ 1, 2, 3, 4 ]
--> [ "3", "1" ]
```

Oops.

I told you that `List.map` and `List.filter` used `List.foldr` which has an overhead, well keeping the order is exactly the reason why.

Fortunately, this can be solved by adding a `List.reverse` on the end result (either in `keepEvenElementsAndMap_2` or in `[] -> acc`) because we didn't mess up the order, we only reversed it.
That would increase the number of times we loop over the list to 2, which is still a lot better than in the first implementation. Maybe there is a more optimal solution out there, but I haven't dived that deep.

But... **do you _need_ to preserve the order?**

Well, sure, in plenty of cases, the order of the list is important and needs to be maintained.
For instance, if you have a list of students sorted by grade, and you wish to have their names from best-performing to least-performing, then you likely to preserve the order.

But if you wish to create a `Set` of student names to know if a student is part of the class, then the order doesn't matter at all.

```elm
namesOfStudentsInClass : List Student -> Set String 
namesOfStudentsInClass students =
    List.map .name students
        |> Set.fromList
```

The "problem" is that we're conflating lists as 1. the data structure where the first element is easily accessible,
and 2. the only Elm collection that has native construction and with a lot of core functions built around.

For instance, you can't really build `Set` natively, you're almost required to start with a list (`Set.fromList [ 1, 2 ]`).
Which is okay, that doesn't necessarily have performance overhead, unless in the intermediate steps you use functions
that have overhead meant to keep specific properties that you don't need.

Here is an implementation of `List.map` that does not guarantee the order (or in a way, is guaranteed to inverse the original order),
written using a recursive style

```elm
altMap : (a -> b) -> List a -> List b
altMap mapper list =
    altMapHelp mapper list []


altMapHelp : (a -> b) -> List a -> List b -> List b
altMapHelp mapper list acc =
    case list of
        [] ->
            acc

        x :: xs ->
            altMapHelp mapper xs (mapper x :: acc)
```

TODO Benchmark image

## What to do with the results?

Well, it's a bit tricky. On the one hand, we have the knowledge that we could have much faster code, and on the other
hand, that code is harder to read or unintuitive (`List.map` that inverse the list for instance).

For most intent and purposes, Elm is pretty fast already, and it's unlikely that you **need** to do much
optimizing in your code. If your app already runs at 60fps, don't bother improvement it further.

When performance doesn't matter, then I highly recommend writing code in the most readable and least surprising way,
using idiomatic Elm functions and structures, notably the functions in `elm/core`. Carefully consider that cost of
writing non-idiomatic code when working in a team.

It's only when you're in dire need of performance that you could reach for more optimization techniques. In my case,
running `elm-review` is an extremely computation-intensive process, especially so on large projects, and improving
performance by a few percent can cut down a few seconds from the entire process.

I haven't tried using these techniques in practice, but I'm going to keep them in my toolbelt,
ready for use where it makes sense. Maybe I'll write another article with results, which could be pretty disappointing 😅

Another thing we can try, is to have the compiler optimize code similar to this for us. Meaning that it could transform
the first example we say (with filterMap+filter+map) into a single foldr call or a single recursive function.
It's very much possible that this will result in larger build assets which could be a problem.

I'd like to experiment this with `elm-optimize-level-2` at some point, which we can use for experimentation.
TODO stream fusion

## Warnings

1. Don't try to prematurely optimize your code.
2. Benchmark the changes.


Check out [my repository](https://github.com/jfmengels/elm-benchmarks) where I put a lot of benchmarks.