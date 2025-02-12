---
title: Tail-call optimization in Elm
slug: tail-call-optimization
published: "2021-06-01"
---

...or if you prefer a clickbaity title: "Tail-call optimization, [what it is](#what-is-tco), [why it's tricky](#why-is-tco-tricky), and [why you won't need to worry about it anymore](#why-you-wont-need-to-worry-about-it-anymore)". But that felt a bit long.

## What is TCO?

Tail-call optimization (TCO) is a very neat trick that the Elm compiler does to make recursive functions a lot more performant and stackoverflow-proof.

Evan Czaplicki [describes it very well in this article](https://functional-programming-in-elm.netlify.app/recursion/tail-call-elimination.html) and I recommend you go read it. He calls it tail-call elimination but it's a different name for the same thing.

To summarize Evan's article, a "tail-call optimized" function is a recursive function that gets compiled to using a loop instead of function calls to itself. Let's take the following code as an example.

```elm
factorial : Int -> Int
factorial n =
    factorialHelp n 1

factorialHelp : Int -> Int -> Int
factorialHelp n result =
    if n <= 1 then
        result

    else
        factorialHelp (n - 1) (result * n)
```

Naively, `factorialHelp` above would get translated to JavaScript code similar to this:

```js
function factorialHelp(n, result) {
    if (n <= 1) {
        return result;
    } else {
        return factorialHelp(n - 1, result * n);
    }
}
```

Instead, the compiler translates it to a function that uses a while loop:

```js
function factorialHelp(n, result) {
    while (true) {
        if (n <= 1) {
            return result;
        } else {
            result = result * n;
            n = n - 1;
        }
    }
}
```

In this version, the function calls are replaced by the less costly re-iteration of a loop.
The function will run faster, and it also won't cause stack overflows because the function won't add to the function call stack.

(For those who like the nitty-gritty details, the following is the real output)

```js
var $author$project$Main$factorialHelp = F2(
	function (n, result) {
		factorialHelp:
		while (true) {
			if (n <= 1) {
				return result;
			} else {
				var $temp$n = n - 1,
					$temp$result = result * n;
				n = $temp$n;
				result = $temp$result;
				continue factorialHelp;
			}
		}
	});
```


## Why is TCO tricky?

This optimization is applied automatically by the compiler, which is nice because that means we don't have to do
anything special like adding annotations to functions or tweaking compiler options.

But since it is only applied under certain circumstances, the downside of is that when it is not
applied, we won't be made aware of it unless we check for it.

Checking it is applied is done by either adding a test that checks there is no stackoverflow with large inputs
(you basically need to create a stack of ~10000 function calls), or by looking at the source code as we did above.

### So what are these conditions?

In my own understanding, the Elm compiler is able to apply tail-call optimization **only** when a recursive call **(1)** is a simple function application and **(2)** is the last operation that the function does in a branch.

**(1)** means that while `recurse n = recurse (n - 1)` would be optimized, `recurse n = recurse <| n - 1` would not. Even though you may consider `<|` and `|>` as syntactic sugar for function calls, the compiler doesn't (at least with regard to TCO).

As for **(2)**, the locations where a recursive call may happen are:
- branches of an if expression
- branches of a case expression
- in the body of a let expression
- inside simple parentheses

and only if each of the above appeared at the root of the function or in one of the above locations themselves.

#### ERRATA

If you read a previous version of this article, I said "Any recursive calls happening in other locations de-optimizes the function.". That is not true.
The compiler optimizes every recursive call that adheres to the rules above, and simply doesn't optimize the other branches which would call the function naively and add to the stack frame. It is therefore possible to have **partially tail-call optimized functions**.

```elm
recurse n =
    if condition1 then
        -- end condition, is not affected by TCO
        n

    else condition2 then
        -- This branch is tail-optimized. A while loop will be added to the function
        recurse (n - 1)

    else
        -- Won't be optimized: will call the function naively and add to the stack frame.
        recurse (n - 1) * n
```

#### TCO through examples

Let's go through what I mean in examples:

```elm
recurse arg =
    -- Allowed because it's the root of the function
    recurse arg
```

```elm
recurse arg =
    if {- Not allowed -} then
       {- Allowed -}

    else 
       {- Allowed -} 
```

```elm
recurse arg =
    case {- Not allowed -} of
        A ->
            {- Allowed -}

        _ ->
            {- Allowed -}
```

```elm
recurse arg =
    let
        a =
            {- Not allowed -}

        b n = 
            {- Not allowed -}

        {c} =
            {- Not allowed -}
    in
    {- Allowed -}
```

The locations are "composable", so we can create new locations by adding a let expression and an if expression for instance:

```elm
recurse arg =
    let
        a n =
            {- Not allowed -}
    in
    if {- Not allowed -} then
       {- Allowed -}

    else 
       ({- Allowed -}) 
```

And that's it! There are no other locations and constructs where recursive calls are allowed!

Let's go through a few examples of non-TCO functions, because I think that this explanation may not be explicit enough as to what is **not** allowed.

### An operation is applied on the result of a function call

```elm
factorial : Int -> Int
factorial n =
    if n <= 1 then
        1

    else
        factorial (n - 1) * n
```

The result of this recursive call gets multiplied by `n`, making the recursive call not the last thing to happen in this branch.
You can think of the `*` expression as having two sub-locations, an expression on the left and an expression on the right,
and neither are locations where recursive calls are allowed (since they aren't in the list of allowed locations mentioned before).

Hint: When you need to apply an operation on the result of a recursive call, what you can do is to add an argument holding the result value and apply the operations on it instead.

```elm
factorialHelp : Int -> Int -> Int
factorialHelp n result =
    if n <= 1 then
        result

    else
        factorialHelp (result * n)
```

and split the function into the one that will do recursive calls (above) and an "API-facing" function which will set the initial result value (below).

```elm
factorial : Int -> Int
factorial n =
    factorialHelp n 1
```


### Calls using the |> or <| operators

As explained above, the following won't be optimized because the function call needs to be a function "application".

```elm
fun n =
    if condition n then
        fun <| n - 1

    else
        n

fun n =
    if condition n then
        (n - 1) |> fun

    else
        n
```

The fix here consists of converting the recursive calls to ones that don't use a pipe operator.


### Calls appearing in || or && conditions

The following won't be optimized, for the same reasons as both `(*)` and `|>`.

```elm
isPrefixOf : List a -> List a -> Bool
isPrefixOf prefix list =
    case ( prefix, list ) of
        ( [], _ ) ->
            True

        ( _ :: _, [] ) ->
            False

        ( p :: ps, x :: xs ) ->
            p == x && isPrefixOf ps xs
```

The fix here consists of using if expressions instead.

```elm
isPrefixOf : List a -> List a -> Bool
isPrefixOf prefix list =
    case ( prefix, list ) of
        ( [], _ ) ->
            True

        ( _ :: _, [] ) ->
            False

        ( p :: ps, x :: xs ) ->
            if p == x then
                isPrefixOf ps xs

            else
                False
```


### Calls from let declarations

Calls from let functions will de-optimize the function.

```elm
fun n =
    let
        funHelp y =
            fun (y - 1)
    in
    funHelp n
```

Note that recursive let functions can be optimized if they are recursive,
but calling the parent function will cause the parent to not be optimized.

### Mutually recursive-calls

Mutually recursive functions will only be optimized if there are any direct recursive calls and they all follow the rules I previously mentioned.

That said, calling the other function will still create a stack frame, just like for a non-recursive function.

```elm
fun1 n =
    if condition then
        -- Will be optimized for this branch
        fun1 (n - 1)

    else
        -- Will create a stack frame
        fun2 (n - 1)


fun2 n =
    -- Will not be optimized
    if condition then
        n

    else
        -- Will create a stack frame
        fun1 (n - 1)
```


## Why you won't need to worry about it anymore

As we have seen above, "misuses" of recursive functions can be found just by looking at the code. And when you're able to see the problem simply by looking at the code, the chances are high that you can detect this problem with [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/).

So I am excited to release [`elm-review-performance`](https://package.elm-lang.org/packages/jfmengels/elm-review-performance/latest/)!

It at the moment contains a single rule named [`NoUnoptimizedRecursion`](https://package.elm-lang.org/packages/jfmengels/elm-review-performance/latest/NoUnoptimizedRecursion), which finds recursive functions and reports when they are not optimized.

Since TCO is not always applicable (I'm pretty sure there are theorems saying that not every function can get this optimization) or easy, there is a way to opt-out of this rule using tag out comments, as described in the rule's documentation. As usual, I think that people should not reach for the ignore comment as fast as they like to do in other languages, but I think that in this case it's a necessary evil if you want to be made aware of new unoptimized recursive functions.

You can try this rule out by running the following command:

```bash
npx elm-review --template jfmengels/elm-review-performance/example --rules NoUnoptimizedRecursion
```


## Afterword

TCO is a technique that is in a way very un-Elm-like because it is not explicit and fails silently. I have wanted `elm-review` to be able to detect this issue probably since before I released `elm-review`, so I am personally very happy that I was able to write this rule.

I was finally unblocked and inspired to write the rule when I finally figured out how it really worked, which is recorded in this blog post for everyone to have the same understanding that I have of it.

I am very curious as to what you will find with this rule, and how you will handle each of these. Please let me know!

I'm pretty sure that the subject of TCO will come up a lot more often from now on. And hopefully issues about it will come up a lot less 😉

If you (or your company) like the work that I've put into this, please consider [supporting me financially](https://github.com/sponsors/jfmengels).

Oh by the way, you'll soon hear more about this package. I could tease you and tell you what I have planned, but I'm feeling a bit... _lazy_.