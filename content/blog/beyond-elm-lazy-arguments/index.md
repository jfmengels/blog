---
title: Beyond Html.Lazy's argument limit
slug: beyond-elm-lazy-arguments
published: "2025-04-26"
---

The Elm ecosystem provides in its core libraries a tool that is amazing for performance of web pages: [`Html.Lazy`](https://package.elm-lang.org/packages/elm/html/latest/Html-Lazy). It allows the runtime from preventing the re-computation of calculations that we know is going to be the same as the last time we ran it, which can make a huge difference in the smoothness of the page.

One of its limitations is the number of arguments that can be provided, which is [8](https://package.elm-lang.org/packages/elm/html/latest/Html-Lazy#lazy8) at the maximum, and I want to provide a workaround that has worked out well for some of my projects. If you're frustrated by this limitation and are okay with patching the JS output of the Elm compilation, then this articule might be useful to you.

If you've already read the article and just want the solution, **[here is the code](https://github.com/jfmengels/elm-lazy-shallow)**.

By the way, if you have other problems with the use of `Html.Lazy` (which can be tricky to use correctly), I helped write a small guide on how to use it well on [Elmcraft](https://elmcraft.org/faqs/html-lazy-not-working/).

I love to do deep dives into the topics I cover so that they become good resources, but I'll try to stick to the topic as much as possible. If you'd like me to do a separate write-up about how laziness works under the hood, let me know—I found it interesting at least!

## The problem

The main problem here—that a sufficiently complex Elm app will hit at one point or another—is that you hit the maximum number of arguments for the lazy API: You were using `lazy8` and you reach for `lazy9` and... it's not there.

```elm
Html.Lazy.lazy9 myViewFunction
    arg1
    arg2
    arg3
    arg4
    arg5
    arg6
    arg7
    arg8
    arg9
```

```ansi
[36m-- NAMING ERROR --------------------------------------------------- src/Main.elm[0m

I cannot find a `Html.Lazy.lazy9` variable:

1|     Html.Lazy.lazy9 myViewFunction
       [91m^^^^^^^^^^^^^^^[0m
The `Html.Lazy` module does not expose a `lazy9` variable. These names seem
close though:

    [33mHtml.Lazy.lazy[0m
    [33mHtml.Lazy.lazy2[0m
    [33mHtml.Lazy.lazy3[0m
    [33mHtml.Lazy.lazy4[0m
```

The knee-jerk reaction is to put some arguments in a tuple `( arg8, arg9 )` or in a record `{ arg8 = arg8, arg9 = arg9 }`. Unfortunately doing that will cause the lazification to fail **always** (I'd love to explain why in a new post wink wink), so that is not an option.

When you hit this point, you can start using some of the workarounds described in the previously linked [Elmcraft guide](https://elmcraft.org/faqs/html-lazy-not-working/). In my projects, we often had to resort to the encoding technique.

The encoding technique would most commonly be converting a few booleans into a single number, and then in the view function's implementation, decoding it right away back into booleans. This is somewhat error-prone and has a bit of overhead (both in terms of code and performance), but it works.

On our most complex part of the UI, we would hit a problem everytime we noticed we needed an additional argument—where laziness was critical for performance—and had to figure a workaround every time.

At some point, this just didn't cut it anymore. We would have too many unencodable pieces of data (such as functions) among the other regular arguments. I remember one place where we would have had 20 arguments if that was naively possible.

So I worked on a new solution, that has worked really well for us ever since.

## Introducing lazyShallow

By introducing a new function whose implementation has to be patched, we can use a single record with an arbitrary number of arguments.

```elm
Html.LazyExtra.lazyShallow myViewFunction
    { lazyDummy = ()
    , arg1 = arg1
    , arg2 = arg2
    , arg3 = arg3
    , arg4 = arg4
    , arg5 = arg5
    , arg6 = arg6
    , arg7 = arg7
    , arg8 = arg8
    , arg9 = arg9 -- OVER 8 ARGUMENTS!!!
    }

myViewFunction params =
  Html.div
    []
    [ Html.text params.arg1
    , ...
    ]
```

On top of the unlimited number of arguments, the arguments can now have names, which is really nice when you hit this number of arguments, and which is not possible with the regular use of `Html.Lazy`.

I can't emphasize enough how well this worked for us. It made some view functions more readable because of the field names. It got rid of the encoding and decoding boilerplate (and their tests!). We could more freely place the lazification where we wanted. And I haven't heard anyone mention any problems about "1 more argument to a lazy function" since.

## How to use it

This is the Elm implementation of the code:
```elm
module Html.LazyExtra exposing (lazyShallow)

lazyShallow func a =
    func a
```

It does basically nothing. It takes a function and an argument, then calls the function with the argument. It looks very unnecessary, but it's exactly what `Html.Lazy.lazy` does if you remove its lazification magic.

When compiled to JavaScript, it looks like this:

```javascript
var $author$project$Html$LazyExtra$lazyShallow = F2(
  function (func, a) {
    return func(a);
  });
```

but we're going to patch it to the following:

```javascript
var $author$project$Html$LazyExtra$lazyShallow = F2(function(func, record)
{
  var args = Object.entries(record)
    .sort(function([key1], [key2]) { return key1 < key2; })
    .map(function([key, value]) { return value; });
  return _VirtualDom_thunk([func].concat(args), function() {
    return func(record);
  });
});
```

The main thing this patched version does is take the fields from the record and put them in an array, just like the underlying lazification function (`_VirtualDom_thunk`) expects.

`_VirtualDom_thunk` takes a list of arguments (and the function) to be compared with the previous/next set of arguments, and a function to run when lazification failed (basically equivalent to our unpatched function).

You can compare it to `Html.Lazy.lazy3` if that helps your understanding.

```javascript
var _VirtualDom_lazy3 = F4(function(func, a, b, c)
{
	return _VirtualDom_thunk([func, a, b, c], function() {
		return A3(func, a, b, c);
	});
});
```

## lazyDummy

Maybe you noticed the `lazyDummy` field in the usage example and were surprised not to see it in any of the implementations.

```elm
Html.LazyExtra.lazyShallow myViewFunction
    { lazyDummy = ()
    -- ...
    }
```

That is because the JavaScript code is expecting the data argument to be an Elm record (which is just a JS object). There's certainly a way to accept any piece of data, but I figured making sure it's a record is probably not a bad idea anyway. Improvement ideas welcome.

So with that goal in mind, how do you write the type annotation for that?

```elm
lazyShallow : (a -> Html msg) -> a -> Html msg
lazyShallow func a =
    func a
```

The above doesn't work. It accepts any data, not just records. If you want a record but don't care about specific fields, then we can use an extensible record in the type annotation. But how do you write it when you don't care about **any** field? `{ a | ... }`? `{ a }` ? Those are not valid syntax. `{}`? That means a strictly empty record.

The answer is that there is no syntax for it. So if you want to make sure it's an Elm record, then you need to have at least one field. One "dummy" field.

```elm
lazyShallow :
    ({ a | lazyDummy : () } -> Html msg)
    -> { a | lazyDummy : () }
    -> Html msg
lazyShallow func a =
    func a
```

The name of the field is in practice not important, you can rename it to whatever.

Similarly, I named the function `lazyShallow` to explicit that it's a shallow lazification, and not a deep recursive lazification, as someone may potentially expect. Again, I've grown accustomed to it, but happy to find a better name (or a better module name).

## Use it in your project

I originally thought about pasting the module code and patch script here, but I figured that maybe the code and—at least—the patch script could be improved (or even provided for multiple build systems), so I decided to create a separate repository for it where people could suggest improvements.

You can find all that here: [jfmengels/elm-lazy-shallow](https://github.com/jfmengels/elm-lazy-shallow).
And please read the warnings about patching your compiled code.

I hope this makes your code easier!