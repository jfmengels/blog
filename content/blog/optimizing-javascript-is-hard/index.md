---
title: Optimizing for JavaScript is hard
slug: optimizing-javascript-is-hard
published: "2022-08-15"
---

JavaScript is a very hard language to optimize, especially as a compilation target. Since [Elm](https://elm-lang.org/) compiles to JavaScript and I occasionally like to try out optimization ideas, optimizing JavaScript is a problem I'm then confronted with.

## On-the-fly optimizations

JavaScript is quite a fast language because of the on-the-fly optimizations that the different JavaScript engines apply at runtime. These are very heuristic-based and dependent on how things are called and how often.

When a function gets called enough times, a function is considered "hot" and gets optimized based on its past usages.

That means that if you call a function with an argument such as `{ a: 1 }` a lot (like a thousand times), this function will at some point be optimized and start performing much better, on the premise that it will keep being called with a similar value.

But if you call it **once** with `{ b: "oops" }`, then the function will revert back to the non-optimized version.

The engine assumed it was always going to be called with an object with a number field `a`. But now that the engine notices it's not always true, it will de-optimize the function, and maybe re-optimize it later with the knowledge that it can also be an object with a field `b`.


## Hard to predict consequences

Unfortunately, some local optimizations can have terrible consequences on optimizations elsewhere. An example of that is me looking into making the underlying mechanism to do record updates (similar to the object spread operator in JavaScript) faster.

```elm
value = { a = 1, b = 2 }
newValue = { value | b = 1 }
```

I wrote a [benchmark for it](https://github.com/jfmengels/elm-benchmarks/blob/master/src/ImprovingPerformance/RecordUpdate.elm). The results? **+85%** speed improvement for running this kind of operation on Firefox, and **+15%** on Chrome. That's amazing!

The caveat of my implementation is that instead of `newValue` being `{ a = 1, b = 1 }` like it would with the current version of compiled Elm code, it would now be `{ b = 1, a = 1 }`. Which is the same, right?

Well not according to JS engines. Just like the `{ b: "oops" }` before, these are considered to be of different "shapes". And that can cause **other** functions that are using this to get de-optimized.

Let's say we have this `sum` function that sums up the value of the `a` and `b` field for every element in an array.

```js
function sum(array) {
  let sum = 0;
  for (let i = 0; i < array.length; i++) {
	  sum += array[i].a + array[i].b;
  }
  return sum;
}
// Example:
// sum([{a: 1, b: 2}, {a: 3, b: 4}])
// --> 10
```

We can benchmark it by creating a array `arr` filled with 10000 elements (`{ a: 1, b: 1 }` to `{ a: 10000, b: 10000 }`). Now, this becomes quite fast because the on-the-fly optimizer notices that there is a pattern for the elements in the array: they always have the shape `{ a: number, b: number }`, which the optimizer then starts relying upon.

But, if at some point in the array, we change the value to have the inverse keys, for instance by running `arr[2000] = { b: 2001, a: 2001 }`, the optimizer freaks out and de-optimizes the operation.

The result? The whole `sum` operation starts performing **4 times slower** than before on Firefox (and 7% slower on Chrome). Just because we changed the order of keys somewhere deep inside an argument.

Doing `arr[2000] = { a: 2001, b: 2001 }` instead (with the "right" order) leads to no performance change, so it's really the order of the keys that impacted performance. The fact that we changed the order of the keys has some very hidden and important consequences.

So while the operation of creating the record is 85% faster, the fact that it can make other parts of the project 75% slower makes this record update optimization absolutely not worth it.

It's also super scary: What other changes did I think of that impacted seemingly unrelated code?


## Difficulty to benchmark

These optimizations usually kick in after a large number of iterations. That means that if you run a function only a few times in the life of your program, it will likely never get optimized by the JIT.

But when you benchmark a function, you will run it a lot of times, thousands or even millions of times, causing it to get optimized. And the opposite can be true as well, where you're not running some code paths enough times for them to be optimized in your benchmarks. Both situations may not reflect what you'll encounter in reality.

When running a benchmark, the engine doesn't tell you what has or hasn't been optimized, or when, or even how (maybe only for `{ a: 1 }`?).

Actually, you can get that information, but that's definitely not the kind of benchmarking that most people do when running benchmarks, including myself (I still don't understand how to do so actually, I just know it's possible with some engines).


## Different engines, different results

The fact that JS engines have different optimization strategies and implementations for the same piece of JS code means that the result can be very different, and that it's hard to pick the "faster version".

While trying to make Elm faster, me and others have had plenty of "aha, this change makes this operation 10x faster on Chrome" followed by "oh... and 2x slower on Safari" (most things get faster in Chrome but slower in Safari or Firefox, don't ask me why).

These engines also keep evolving. So maybe a change that led to slower code at one point will turn out to be faster on a newer version of engine X (no, not talking about NGINX). I can imagine the opposite being true as well sometimes, though I don't know if that ever happens in practice.

But when do you revisit these optimization ideas? After every new browser version release?

Since these investigations are quite time-consuming, we rarely revisit ideas in practice. If at any point in time we noticed "Oh it's slower in Firefox" then we throw the idea away. But maybe someone else will have the same idea later on and try it out, and figure it's faster.

So maybe I should not document my findings like the one above? Because if I do, people will read them and figure out "okay, that idea doesn't work, let's not try it". I save them time for sure, but maybe I caused a potential improvement not to be tried out again and added in the future.


## Losing information from source to target language

In Elm, if you do `a + b`, that necessarily means that both `a` and `b` are numbers. This operation is taking the value of `a`, taking the value of `b`, adding them as numbers, and returning the value. That's it, nothing else.

That code compiles down to `a + b` in JavaScript, which seems correct and unsurprising. But because `+` on JavaScript can also work for strings (technically also for objects, arrays, functions, and pretty much anything), the addition operation is in fact a lot more than just adding two numbers.

According to the [JavaScript specification](https://tc39.es/ecma262/multipage/ecmascript-language-expressions.html#sec-addition-operator-plus), `a + b` will be equivalent to the under-the-hood `ApplyStringOrNumericBinaryOperator(a, "+", b)` function call (paraphrasing slightly for the explanation), whose specification can be found [here](https://tc39.es/ecma262/multipage/ecmascript-language-expressions.html#sec-applystringornumericbinaryoperator).

Basically, it does this:

[EXPLANATION START] If the operator is "+" (which it is), then it transforms both `a` and `b` to "primitives" through some "abstract operation" (which can be a complex operation as well, though not so much for numbers).

Then it checks whether any of these primitives are strings (they aren't in this case), in which case it transforms them into strings, concatenates them and returns the result.

Because they're not strings, both are transformed to numeric values according to another abstract operation, which in this case is doing no conversion.

Then we check if the types of both are different, in which case a `TypeError` is thrown. We check if one of them is `BigInt`, which is not the case, so we'll skip that handling. Then we look up the operation to be applied for the "+" operator (which is the abstract operation [`Number::add`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-add)), which we then use to **finally add the two numbers**.
[EXPLANATION END]

These are a lot of operations (some of which I skimmed over) for what looks like a very simple operation.

It is frustrating to me that we can't share the knowledge that we have about Elm code (something is definitely a number, something is definitely a string, ...) to the JavaScript runtime. We can't use the `Number::add` operation directly because that is not part of the exposed JavaScript language. Therefore, we can only compiled `a + b` to... `a + b`.

I believe we could make Elm code perform much faster if we had direct access to these building blocks, or if we could give some hints to the runtime that these are numbers for sure.


## Optimizing is guessing

Is it useful to have JIT and on-the-fly optimizations for JavaScript? Yes, because it makes JavaScript a *lot* faster than what it would otherwise be. But it makes optimizing the code a guessing game.

How does this engine optimize this code? Is X faster, or is Y faster? How does this operation get optimized in this benchmark? How does this operation get optimized in real situations?

Not easily being able to figure out the answer to all of these questions makes it very hard to optimize a language that compiles to JavaScript.
Because it's hard to find the changes that make the code run faster for every JS engine, and to discover the consequences of the changes in seemingly unrelated functions.

In a way it's a guessing game because that's what the optimizer does as well: guess that a piece of code will always behave like what it has seen before and roll with that.

I believe that having a compilation target that doesn't do on-the-fly optimizations would be easier to optimize for because there would be less guessing and more transforming code to something that is known to be fast, just like we do when compiling to machine code. 

Would this be different if we were to compile Elm to WebAssembly? I don't know.

From a quick search, it does seem like it is possible to do JIT for WASM, so I wouldn't be surprised if browsers decided to add on-the-fly optimizations to get an edge over competitors if they figured it was worth it. But I might be wrong, don't take my word for it.
(I have just been told that the WASM committee seems to be tired of this kind of optimizations, but I don't have a source link to verify it).

One part where I believe things would improve is for the basic operations like addition, where Elm would be able to teach the runtime that "these are numbers, just add them".


## Learning more

If you're interested in learning more, [Robin Hansen](https://twitter.com/robheghan) wrote [a great suite of articles](https://blogg.bekk.no/successes-and-failures-in-optimizing-elms-runtime-performance-c8dc88f4e623) explaining his process, successes AND failures at optimizing the compiled JavaScript for Elm code. It goes into a lot more depth that this article.

We talked about Elm and WebAssembly more on this [podcast episode](https://elm-radio.com/episode/optimizing-elm), again with Robin.

If you're interested particularly about the performance of JavaScript "shapes", go read the excellent [What's up with monomorphism?](https://mrale.ph/blog/2015/01/11/whats-up-with-monomorphism.html).

I also have a [repository with benchmarks](https://github.com/jfmengels/elm-benchmarks) for a bunch of optimization ideas. Though maybe I shouldn't be sharing this with you.