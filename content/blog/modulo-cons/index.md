---
title: Tail recursion, but modulo cons
date: '2022-02-28T11:59:00.000Z'
---

![](RecursiveTree.jpeg)

If you have been programming for a while, you must have heard about recursion at one point or another.
If you work with Elm or other functional programming languages, chances are high you use it regularly ([even though you
may prefer alternatives](https://twitter.com/jfmengels/status/1480629055808589825)).

A recursive function is a function that calls itself anywhere in its implementation.

Here's a textbook example of recursion, implementing the factorial function (`n!`) in Elm:

```elm
factorial n =
    if n <= 1 then
        1

    else
        n * factorial (n - 1)
```

In my experience, a lot of recursive functions deal with lists. Here is for example
an implementation of `List.map`:

```elm
map : (a -> b) -> List a -> List b
map fn list =
    case list of
        [] ->
            []

        x :: xs ->
            fn x :: map fn xs
```

If you like recursion like I do, you may find it pleasing. It's elegant, concise, simpl... Sorry, what did you say? Stack overflows? Oh, right... 🤦‍♂️


## Making recursion stack-safe


As you have rightfully pointed out, dear reader, the above implementations of `map` is not stack-safe (and neither is the `factorial` one).
You may have read [my article](/tail-call-optimization) explaining when an Elm function is tail-call recursive or not. I recommend
reading it, but I'll give a short summary here.

Everytime a function is called, we add to the "call stack", and every time a function exits and returns a value, we remove from the call stack.
This call stack has a limited size in practice (in the ballpark of 10000 function calls). Under certain conditions,
the Elm compiler can reduce usage of the stack by transforming the body of a recursive function into a loop, which is
a technique named Tail-Call Optimization (TCO).

The main condition for this optimization to apply is for the recursive call to be
the last operation in the function, or said differently to be the direct return value.

For instance, the following function is tail-call optimized:

```elm
find : (a -> Bool) -> List a -> Maybe a
find predicate list =
    case list of
        [] ->
            Nothing

        x :: xs ->
            if predicate x then
                Just x

            else
                find predicate xs
```

And it will be compiled to the following JavaScript code (ignore the `F2` part, [it's unrelated](https://blogg.bekk.no/how-elm-functions-work-71cab7426a2f)):

```js
var find = F2(
	function (predicate, list) {
		find:
		while (true) {
			if (!list.b) { // Checks whether `list` is empty
				return $elm$core$Maybe$Nothing;
			} else {
				var x = list.a;
				var xs = list.b;
				if (predicate(x)) {
					return $elm$core$Maybe$Just(x);
				} else {
                    // Prepares the variables for the next iteration
					var $temp$predicate = predicate,
						$temp$list = xs;
					predicate = $temp$predicate;
					list = $temp$list;
                    // Goes back to the beginning of the loop
					continue find;
				}
			}
		}
	});
```

Going back to our `map` example, the last operation that we do is not the recursive call to `map`, but adding a value to
the beginning of the returned value (`fn x :: ...`).

So how **can** we make it tail-recursive? A common solution is to add an argument acting as an accumulator:

```elm
map : (a -> b) -> List a -> List b
map fn list =
    mapHelper fn list []

mapHelper : (a -> b) -> List a -> List b -> List b
mapHelper fn list acc =
    case list of
        [] ->
            acc

        x :: xs ->
            mapHelper fn xs (fn x :: acc)
```

It's a bit more verbose, but it's not that bad. Honestl... Sorry, what did you say? Wrong order? Oh, right... 🤦‍♂️

Yeah, if you run this function, you will notice that the result is in the reverse order of what they should be
(`[ 3, 2, 1 ]` instead of `[ 1, 2, 3 ]` for instance). And that's because the last `x` will be at the very start of the
accumulator, and inversely the first `x` will be at the very end.

So... we'll just add a small `List.reverse` on the accumulator at the very end... It will hurt performance quite a bit
but correctness is more important.

```elm
mapHelper : (a -> b) -> List a -> List b -> List b
mapHelper fn list acc =
    case list of
        [] ->
            List.reverse acc

        x :: xs ->
            mapHelper fn xs (x :: acc)
```

Surely we can do better than this, right?! Let's take a look at how `List.map` is implemented in the core library.

```elm
map : (a -> b) -> List a -> List b
map f xs =
  List.foldr (\x acc -> f x :: acc) [] xs
```

That's surprisingly simple. The order is right because the list is being visited in reverse order (that's what `foldr`
does, in contrast to `foldl`). But we need to look at the implementation of [List.foldr](https://github.com/elm/core/blob/master/src/List.elm#L172-L206)
to see if we can reuse the same idea for our custom functioOH GOD CLOSE THE TAB!

Ugh... if you've opened the link, you know that we have gone far from the elegant solution described at the beginning.
That said, I don't want to throw any shade. Even though it looks complex, it's a lot faster than other solutions, and
I'm in awe of the one who figured this out. Thanks [Robin](https://twitter.com/robheghan)!

Implementing every one of our recursive functions à la `List.foldr` is not reasonable nor maintainable in my opinion.

So instead of going for recursion, we could go with `List.foldr`, but depending on the function it may not be appropriate.
For instance, when you want to terminate the iteration early (`find`, `any`, ...). Also, `List.foldr` is a lot slower
than `List.foldl`.

Whatever choice we end up making for our recursive functions, we incur both a performance cost and a readability cost.
And all of that basically because we can't add an element to the beginning of the result of a recursive call in a stack-safe way...

But what if we could?


### Building the list using mutation

Since my last blog post, I was exploring a bunch of ideas to make Elm code faster, and in particular list iterations.

After benchmarking them, I found some good and promising results in some of my explorations. Then I learned, the hard way,
that I also should have been comparing it after the code was optimized using [`elm-optimize-level-2`](https://github.com/mdgriffith/elm-optimize-level-2),
which is a tool that optimizes Elm code to be more performant (in part as a means to explore optimizations so that they
can one day be integrated back into the Elm compiler).

The result was that my explorations tended to be slower than expected in the comparisons that I made, the reason being
that some `List` functions had had their implementation replaced by a much more performant one using mutation,
handwritten in JavaScript.

For instance, `List.map`'s implementation was replaced by the following:

```js
var $elm$core$List$map = F2(function (f, xs) {
  var tmp = _List_Cons(undefined, _List_Nil);
  var end = tmp;
  for (; xs.b; xs = xs.b) {
    var next = _List_Cons(f(xs.a), _List_Nil);
    end.b = next;
    end = next;
  }
  return tmp.b;
});

// For reference, this is _List_Cons:
function _List_Cons(hd, tl) { return { $: 1, a: hd, b: tl }; }
```

In short, what this implementation does is to create a value (`tmp`) holding an initially empty list (`_List_Nil`, stored in `tmp.b`), and a pointer to the current
end of the list (`end`). Then we iterate through the list, and as long as there are elements in it, we add them to the `end` of the
list and update the reference to the end. When the iterating is over, we return the start of the list (`tmp.b`)
which will by then contain all the elements.

I found it to be pretty smart, and started thinking of how to apply this to more `elm/core` functions — which wasn't too
hard, so I made a few pull requests to `elm-optimize-level-2` (some of them available in the latest version) — but also
to non-core code that deal with lists, and came up blank.

After a while, I discovered [this thread](https://discourse.elm-lang.org/t/a-faster-list-map-for-elm/6721) that I had totally missed, which was the
original announcement for the improvements described above made by Brian Carroll, and the term "Tail Recursion Modulo Cons" came up. And oh man,
sometimes you just need to know that something exists or to know how something is called to unblock you, and unblocked I was.


### Tail recursion, but modulo cons

Tail Recursion Modulo Cons (TRMC) is a technique described back in the 1970 which allows tail optimization to be applied
when an operation is applied on the result of a recursive call, as long as that operation is only "cons"tructing data,
such as with the "cons" (`::`) operator.

The issue with an operation like `someFunction x (recursiveCall n)` is that `someFunction`'s behavior and return value are
*dependent* on the result of the recursive call, and we therefore need to postpone that calculation until we have
evaluated the recursive call. We tend to do that with stacks: either implicitly with the call stack (which is limited in size)
or explicitly with an accumulator argument.

But there are cases where we *could* call `someFunction` **before** making the recursive call, and the simplest example are
functions that construct a record where each field is independent. If we have a function `create x y = { x = x, y = y }`,
we could call `create` with a "hole" value for one of the arguments (`y` for instance) like `create 1 <hole>`, and in a
later iteration (before the value gets accessed) mutate the value to set the `y` field. And that's basically what TRMC is doing:
creating data with holes then filling up the holes later.

Let's say we have this definition for `List` (close to the truth) and this version of `map`:
```elm
type List a
  = Nil
  | Cons a (List a)

map : (a -> b) -> List a -> List b
map fn list =
    case list of
        Nil ->
            Nil

        Cons x xs ->
            Cons (fn x) (map fn xs)
```

Applying TRMC could produce the following JS (redacted for clarity):

```js
const Nil = {$: 0};
function Cons(head, tail) {
    return {
        $: 1,
        a: head,
        b: tail
    };
}

var map = function (fn, list) {
    // Create an accumulator which we'll return at the end
    var $start = { b: null };
    // Create a variable that contains a reference to the "hole"
    // that we will fill in the next iteration 
    var $end = $start;
    map: while (true) {
        if (list.$ === 0) {
            // If list is Nil, assign the return value (Nil) to the end,
            // filling the remaining hole.
            $end.b = Nil;
            // and return the root value, now containing the entire structure
            return $start.b;
        }
        else {
            // If list is Cons x xs
            var x = list.a;
            var xs = list.b;
            // We create a value with a null hole, computing `fn x` but
            // leaving the computation of the recursive call for later.
            var newEnd = Cons(fn(x), null);
            // We fill in the previous hole with the new value
            $end.b = newEnd;
            // And we update the reference to the end of the list
            $end = $end.b;
            // Updating the values for the next iteration and re-iterating
            list = xs;
            continue map;
        }
    }
}
```

This produces the same result as a non-optimized `map` implementation, but is stack-safe.

## TRMC in practice

So I didn't only investigate TRMC, I also worked on an implementation. Currently, there's an
[open PR to apply this optimization](https://github.com/mdgriffith/elm-optimize-level-2/pull/82). So if you want to try
it out, please do!

One word of caution though: Any code that will benefit from this optimization will be stack-unsafe when compiled with
only the Elm compiler, so please only write code this way in applications (not in published packages) and if you know
you will use `elm-optimize-level-2` to optimize the code.

Now that you know this, let's do a small happy dance and get back to talking about the optimization.


## Supported operations

Because `elm-optimize-level-2` works by taking the Elm compiler's JavaScript code output, my implementation works by transforming
JavaScript code, meaning I had to reimplement tail call recursion from scratch.

A benefit from that, is that recursive function calls like `recursiveCall <| n`, which don't get optimized by the Elm
compiler ([see why](/tail-call-optimization)), are now optimized. Since this is one of the most common issues with failing TCO, this satisfies me greatly.

I also made it so that recursive calls done like `condition || recursiveCall n` or `condition && recursiveCall n`
benefit from TCO, as well, preventing the need to write [some comments](https://github.com/elm/core/blob/1.0.5/src/List.elm#L298).

Now on to TRMC-specific operations.


### Data construction

The main application for TRMC is for constructing data whose shape is recursive in a predictable way. We have seen the
example with a custom `List` above already.

For now, my implementation only supports building things using custom type constructors as functions
(`Cons x (recursiveCall n)`) but not using functions (`cons x (recursiveCall n)`). Later on and with some more code
analysis, we could probably apply this to any function call where the function stores the value in a predictable location,
regardless if it's a custom type constructor, a type alias constructor or a custom function.

And it also doesn't support storing in nested data structures like `MyRecord { field = Ok (recursiveCall n) }`, but this
could absolutely be done given some work.

Because TRMC needs predictable locations for the holes, TRMC will likely not be a good candidate for working with Elm
`Array` and `Dict`/`Set`, because under the hood these are represented as trees that get re-balanced, making it hard to
know whether the hole is the left tree node or the right tree node for instance.


### List operations

`List` in Elm is a normal "custom" type, with the exception that there is special syntax to construct it and operators
to interact with it.

In addition to supporting recursion for `f x :: recursiveCall n`, which makes the `map` implementation presented at the
beginning stack-safe, my implementation also supports concatenating to the result of a recursive function (`f x ++ recursiveCall n`),
which I often encounter when dealing with trees (ASTs at the very least).

The following contrived example is stack-safe with TRMC.

```elm
type SomeCollection a
    = Empty
    | OneItem a (SomeCollection a)
    | TwoItems a a (SomeCollection a)
    | ArbitraryNumberOfItems (List a) (SomeCollection a)


flatten : SomeCollection a -> List a
flatten collection =
    case collection of
        Empty ->
            []

        OneItem a rest ->
            a :: flatten rest
            
        TwoItems a b rest -> 
            a :: b :: flatten rest
            
        ArbitraryNumberOfItems list rest -> 
            list ++ flatten rest
```

Also, we can add a list to the end of the result of the recursive call (`recursiveCall n ++ f x`), in which case we'd
create an additional accumulator for everything that gets appended to the end that way, which would be updated at every
iteration using a relatively cheap operation (akin to `$tail = f x ++ $tail`) and appended once on exit (`$end.b = $tail; return $start;`). 

### Number operations

In addition to data construction where we create holes, TRMC also works for types and operations that are commutative,
associative and have a neutral value. More concretely, TRMC supports recursive function calls that apply `+` or `*`
(exclusively) on the result of a recursive call.

Simple examples include the factorial example presented at the start, and functions like sum and product:

```elm
sum : List Int -> Int
sum list =
    case list of
        [] ->
            0

        x :: xs ->
            -- "sum xs + x" would also work
            x + sum xs

product : List Int -> Int
product list =
    case list of
        [] ->
            1

        x :: xs ->
            -- "product xs * x" would also work
            x * product xs
```

The corresponding JS code would create an accumulator with a neutral value (0 for `+`, 1 for `*`) which would be modified
every time we see the operation being applied on the result of the recursive function.


### String operations

Similar to number operations, we can also append strings to the result of a recursive call. And just like lists, strings
can be appended on either (or both) sides of the recursive call.

```elm
pad : Int -> String -> String -> String
pad n padding str =
    if n <= 0 then
        str

    else
        padding ++ pad (n - 1) padding str ++ padding
```


## Benefits

### Stack safety

Stack safety is important, because stack overflows are one additional way for our programs not to behave as we expect
them to and/or to create problematic behavior for our users. Therefore, reducing the amount of stack-unsafe functions
and/or knowledge required to write a function in a stack-safe way is a huge win.


### Simpler functions

A lot of recursive functions are made complex solely because they try to achieve stack safety. For instance, for any
function that needs to accumulate data (`List.map` for instance, but not `List.Extra.find`), you need to define an
accumulator argument. But also, since you don't want to expose this accumulator argument to the developer that uses the
function, you need to split the function into a public one and a "helper", or define a helper in a let declaration.

I went through all of `elm/core` and `elm-community/list-extra` and rewrote most of the recursive functions (including for
`elm/core`, some of which were written in JavaScript), and I'll let you be the judge of whether functions are now simpler or not:

- [elm/core](https://github.com/jfmengels/core/compare/2fa34772a2575d036c0871b4390379741e6f5f91...new-tail-recursion)
- [elm-community/list-extra](https://github.com/elm-community/list-extra/compare/master...jfmengels:new-tail-recursion)


## Performance

For the bundle size, the compiled output is larger than without TRMC. It's hard to measure by how much for a total
project though, because it depends on how often it gets applied. From my shallow testing though, the bundle size barely
increases by that much after minification and gzip.

As for speed, I'd like to make a joke about how TRMC makes functions slower, but no, TRMC-optimized code goes from being
just as fast as stack-safe alternatives code, to being several times faster, especially for lists because we can avoid
reversing lists and similar operations.

You can find some benchmarks in a dedicated folder of [`jfmengels/elm-benchmarks`](https://github.com/jfmengels/elm-benchmarks/tree/master/src/TailCallRecursionExploration),
but we can take `List.map` as an example, with the implementation from the beginning. According to
[its benchmark](https://github.com/jfmengels/elm-benchmarks/blob/master/src/TailCallRecursionExploration/ListMap.elm),
`List.map` is around 7x faster on Chrome than the `elm/core` version. It's surprisingly even faster than the hand-written one that Brian Caroll made (+7% on Chrome, +45% on Firefox) and that is currently in `elm-optimize-level-2` (don't ask me why it's faster though. `while` faster than `for` maybe?).

When there is no need to accumulate data or little cost to it (like a
[factorial](https://github.com/jfmengels/elm-benchmarks/blob/master/src/TailCallRecursionExploration/Factorial.elm) function),
then TRMC is about as fast as the TCO version.

I don't want to advocate for using recursion instead of folding with functions like `List.foldl`/`List.foldr`,
but from now on, my nose smells a performance improvement opportunity every time I encounter `List.foldr`, which can be a lot
slower than Tail Recursion Modulo Cons, at least for lists.

For now, the only performance decreases I could notice are when doing multiple recursive calls in a single expression,
such as in tree-like data structures (think `TreeNode (recursiveCall left) (recursiveCall right)`). At the moment, my
implementation turns one of the recursive calls into a while loop (or rather, into a `continue`), which I believed
should improve performance but actually does the opposite. Obviously this is something to be looked at further and hopefully fixed.


### Afterword

If you'd like to learn more about this, I tried to [document the optimization](https://github.com/jfmengels/elm-optimize-level-2/blob/tail-call-recursion/src/transforms/tailCallRecursion.ts)
well, and there are [tests](https://github.com/jfmengels/elm-optimize-level-2/blob/tail-call-recursion/test/determineType.test.ts) to give you more examples.

When people are taught recursion in school, they get examples like the ones I described before.
I find these solutions very elegant, and they feel very simple once you grok recursion. But they are in practice unusable
because they are not stack-safe (at least in non-lazy languages like Elm. Haskell is a different story).

But with Tail Recursion Modulo Cons, well they are.

I'll just leave you with this snippet of code that is elegant, concise, simple, **stack-safe**, performant, and therefore in my eyes: beautiful*.

```elm
map : (a -> b) -> List a -> List b
map fn list =
    case list of
        [] ->
            []

        x :: xs ->
            fn x :: map fn xs
```

*serving suggestion. Variable names may be different when implemented yourself. 


Thanks to Robin Hansen for reading through the draft and giving feedback ❤️