---
title: The caching behind Elm's Html.Lazy
slug: caching-behind-elm-lazy
published: "2025-05-11"
---

`Html.Lazy` is an amazing module for Elm performance. I recently wrote about going [Beyond Html.Lazy's argument limit](/beyond-elm-lazy-arguments), and I have helped write about how to work with it on [Elmcraft](https://elmcraft.org/faqs/html-lazy-not-working/).

Today, I'd like to go into how Html laziness works, as I found it to be quite interesting back when I looked into it.

We'll start from a broad perspective but always with a focus on laziness, and then we'll go into the characteristics of this peculiar caching mechanism. We'll end by looking into new variants for lazy functions.

## Step 1 - Calling view and getting a virtual DOM

The first step in the process is the Elm runtime calling the `view` function defined in your `main` function. This `view` function returns `Html msg`, which under the hood is a tree of virtual DOM nodes.

When you use functions like `Html.span` or `Html.text`, the resulting data is plain JavaScript objects that describe the HTML nodes that should be generated (including attributes, properties, event handlers, ...).

```js
// Given: Html.text "Hello"
var node = {
  $: __2_TEXT,
  __text: "Hello"
};

// Given: Html.span [] [ Html.text "Hello" ]
var node = {
  $: __2_NODE,
  __tag: "span",
  __kids: [ { $: __2_TEXT, __text: "Hello" } ],
  __facts: {}, // attributes from the first list argument
  __namespace: undefined, // not relevant
  __descendantsCount: 1 // number of kids, recursively
};
```

(Note: these field names are the ones in the source code for `elm/virtual-dom` in. All these fields will be renamed at compile-time, so this won't match what you see in the compiled JavaScript code)

That's it for regular nodes. Now, let's look at `Html.Lazy.lazy`. I'll briefly skip the implementation for now, as I want to focus on the main underlying function — `_VirtualDom_thunk` — whose implementation is the following:

```js
function _VirtualDom_thunk(refs, thunk)
{
	return {
		$: __2_THUNK,
		__thunk: thunk,
		__refs: refs,
		__node: undefined
	};
}
```

The node kind is a "thunk" node and it stores a thunk. A thunk is a function without arguments, which in Elm means it will always return the same value. In this case, the thunk is a function that will return a new virtual DOM node, the one to be rendered.

`refs` is what we're going to use to determine whether we need to re-evaluate the thunk. We'll dive into this very soon.

Very related to that, `node` stores the result of calling `thunk()`. It's always initially set to `undefined`, but we'll see that it gets updated later.

As you can see, contrary to the `Html.span` example, we don't know the children of this node (at least until it gets computed and stored in `node`), we only have a function to compute the children.

Virtual DOM functions (and their more user-friendly `Html` wrappers) are eager in their creating of the tree, while `Html.Lazy.lazy` is... well, aptly named.

### Contents of refs

So, `refs`. What does that contain? For that, we need to look at the implementation of the different lazy functions. Let's take the example of `Html.Lazy.lazy2`:

```elm
lazy2 : (a -> b -> Html msg) -> a -> b -> Html msg
lazy2 func a b =
  VirtualDom.lazy2 func a b
```

which points to this JavaScript kernel function (simplified a tiny bit for readability):

```javascript
var _VirtualDom_lazy2 = function(func, a, b) {
	return _VirtualDom_thunk([func, a, b], function() {
		return func(a, b);
	});
};
```

It's a pretty small function, I wasn't lying when I said that `_VirtualDom_thunk` was the main underlying function.

In Elm—because of referential transparency—we know that if a function gets called with the same arguments, then the output will be the same. So, to determine whether we will later need to call the function or whether we can skip it, we store the function and all its arguments. That's exactly the contents of `refs` — in the shape of a JavaScript array — and it will be used in step 2.

## Step 2 - Diffing the virtual DOM

Now that the `view` function has been called, we have a full virtual DOM (except for the lazy parts that have not yet been computed). The Elm runtime will now compare this new virtual DOM with the one it had at the previous render, in order to figure out a list of patches to apply to the real DOM (which is step 3).

Roughly, the [diff algorithm](https://github.com/elm/virtual-dom/blob/1.0.3/src/Elm/Kernel/VirtualDom.js#L697C10-L697C26) walks through both virtual DOM trees and compares every node it encounters to its counterpart in the other tree. If the types (`__2_NODE`, `__2_TEXT`, etc.) differ, then it throws away the old one and adds "rendering the new node" to the list of patches.

It's when the two nodes are of the same type that the algorithm tries to get more subtle and change only what's necessary. But this is not a blog post into virtual DOM diffing, so I'll focus on the [diff of two lazy nodes](https://github.com/elm/virtual-dom/blob/1.0.3/src/Elm/Kernel/VirtualDom.js#L748-L766) (`__2_THUNK`).

Here `x` is a node from the old tree and `y` the counterpart on the new tree.

```js
var xRefs = x.__refs;
var yRefs = y.__refs;
var i = xRefs.length;
var same = i === yRefs.length;
while (same && i--)
{
	same = xRefs[i] === yRefs[i];
}
if (same)
{
	y.__node = x.__node;
	return;
}
y.__node = y.__thunk();
var subPatches = [];
_VirtualDom_diffHelp(x.__node, y.__node, subPatches, 0);
subPatches.length > 0 && _VirtualDom_pushPatch(patches, __3_THUNK, index, subPatches);
```

Roughly, we compare the two `refs` of the two nodes and we do a JavaScript `===` check on each element.

If they're all the same, then we know the function and its arguments are the same, and therefore that the result will have to be the same. We take the result of the computation from the previous node and store it in the new one (`y.__node = x.__node`), which we might use in a later iteration, and we skip doing anything more on this node and the sub-tree (using the early `return`).

If they're not the same, then we have a new function or a new argument. That might yield a different result as the last render so we compute the thunk of the new node and store the result (`y.__node = y.__thunk()`) for a later comparison.

If you use `Html.Lazy.lazy`, **this** is the time where your function gets evaluated, way after your root `view` has finished evaluating (well, not that much after in practice).

We then go through the sub-trees and register all the patches for differences that were found. Note that the diffing of the sub-trees is entirely skipped when lazy succeeds.

Because of the use of `===`, the comparison of `refs` has a lot of false negatives (cases where the data is in practice the same but fails the lazy check anyway. Refer to the [Elmcraft article](https://elmcraft.org/faqs/html-lazy-not-working/#understand-what-constitutes-a-changed-value) for a bit more explanation or help with that) but is extremely fast, there is very little performance overhead even when caching fails constantly.

This means you could sprinkle `lazy` around your codebase without checking whether it caches things well and you'd probably not notice a performance decrease.

#### Diffing for the initial render

What about the first render, when there is no previous render to diff against? Before rendering the first time, Elm creates a virtual DOM out of the DOM node where it should mount. This is called “virtualization” in the code.

During the first render and therefore first diff, the runtime will diff against that virtualized node. Elm apps are usually mounted in an empty DOM node, so in practice the first render diffs against virtual DOM for an empty `div` or empty `body`, which means that the patches will mostly say "insert all of these missing elements".

## Step 3 - Rendering

Now that we have a list of patches, we can modify the real DOM. If this is the initial render, then it's just about creating the DOM nodes corresponding to the virtual DOM. If it's not, then it's more about patching the DOM.

If a node is very different, for instance if we went from the `Html.text "some thing"` to `Html.span [] [ someButton ]`, then we would — again — create the DOM node corresponding to the virtual DOM node, and then replace the old DOM node by the new one (using [`replaceChild`](https://developer.mozilla.org/en-US/docs/Web/API/Node/replaceChild)).

For lazy nodes, we may or may not have the DOM tree yet under the `node` because it is possible that the lazy node was in a sub-tree of a node that was too different from its counterpart, therefore the thunk was never evaluated. In which case, we compute it and store it. This is the other instance where the lazy function might be evaluated.

When all the patches have been applied, we're done with the process. The runtime will then wait until a new `Msg` is triggered before calling `update`, `view` and goes through the diff process again.

## The caching mechanism

Before looking into it, I didn't know this was how it worked. I imagined there was some kind of global cache used by the runtime but didn't know the details, like what the cache keys were, but especially how the runtime made sure this cache's size would be kept in check.

We have now learned how the caching mechanism of `elm/html`'s `Html.Lazy` module works. In summary, the result of the computation is stored in the virtual DOM tree to be compared, with the function and arguments as the cache key, and the cache result is transferred to newer virtual DOM trees if the cache key stays the same.

I find the technique quite clever, even if it's quite limited. Let's go through a few implications.

#### Delaying of computation

This delays when the view function is called. In a language where it matters more when or if functions get called (one with side-effects for instance), this would be scary or tricky to explain (you'd need to read an article like this one). And in a language where runtime errors or exceptions is common, the process would have to be a lot more careful to handle them in a reasonable manner.

#### Limited re-use of caching

If the lazy node ever disappears, then the caching disappears as well. That can happen if it's ever removed from the contents of the `view` function, if it gets moved elsewhere (too far for the diffing algorithm to recognize it's the same). And duplicating the same node elsewhere in the tree won't re-use the same cache, instead it would create two.

Only the last render is remembered. If you switch from `lazy view A` to `lazy view B` and then back to `lazy view A`, then `view` will be re-evaluated again. There's no caching of previous runs, only of the last one, singular.

A global cache could be a lot more performant than this because it could remember more, which would prevent the re-computation of the function.

This is obviously a bit of a shame, but it's better for performance if we start thinking about memory usage.

#### Memory usage

The memory taken by this caching solution is only a single virtual DOM node, which also happens to be the most up-to-date, so it's basically free.

The function and its arguments are also stored. That memory was already allocated so that's free again, but having it stored might therefore delay the garbage collector from freeing them. But if these are objects, then either you kept a reference to them somewhere or at the next `view` call the lazy check will fail, which means it won't be delayed by much. Overall, I'd say this part is very cheap too.

Remember though that if you use `lazy` at the root of your `view` (which is a pretty good idea by the way), then this virtual DOM is your entire DOM.

If we were to store multiple versions such as through a global cache, then for very large pages, keeping a wider history could make your application use a lot more memory which would be terrible for performance.

## New designs

The current design of the lazy mechanism is one that is hard to use correctly because of the many check failures when doing the checking, but it is designed for simplicity (no major footguns) and great performance: key checking is fast and the memory footprint is the same as without caching. You can sprinkle it at will with little worries.

Now that we know the limitations and its tradeoffs, I think it's interesting to figure out how we can stretch this in new API additions (on top of the currently existing one).

#### Deep equality checks

The major pain point with laziness is the rate of check failures with the use of JavaScript's
`===`.

If instead we were to use Elm's `==`—which does a deep equality check—there would be a lot more check successes (But remember that the first item in the `refs` array that we compare is a function. Elm's `==` throws an error when comparing functions. So we would need a slightly different version that doesn't crash for functions and probably falls back to JS' `===` for them).

The check could have "significant" performance implications in the worst case, for instance if one of the arguments is a very large `Dict` that is only slightly different from the last run.

In most cases though, even if a some parts of data have new references, others would stay the same (ex: all the untouched fields of a record in a record update like `{ a | b = c }` keep the same reference), and under the hood Elm's `==` uses JS' `==` as the first check, as that it's faster. So even if it's a deep equality check, not everything will have to be compared, making the speed of such a check likely good enough for most cases.

It's useful to note that what matters is mostly whether the check is slower or faster than the function we're trying to avoid recomputing. If it's faster, then it's likely good enough.

In rarer cases, the current lazy is really hard nay impossible to use because a new object has to be created at one point or another. This version of lazy would shine in those cases.

This wouldn't be as free as the current mechanism as the check itself could *potentially* cause slowdowns, but it is a lot more intuitive and easy to use. This approach is the default in [Gren](https://gren-lang.org/)'s version of `Html.Lazy`.

#### Remembering more previous runs

I think there could definitely be an addition of lazy nodes that remember more results by storing a list (or similar) of previous key+results and checking them all.

There would be more things to check and store so the cost would increase slightly.

The risk is that the memory increases too much, so it would likely be a good idea to limit the size of the cache (e.g. only 5 key+result pairs) and/or to figure out how to clean it regularly.

This could be interesting for expensive views that quickly switch between a limited number of views, for instance with static tabs.

#### Remembering using a global cache

This is obviously the scariest one, where we'd have to be very wary of it growing in size and causing memory leaks.

But storing the results in a global cache could be great for oscillating elements (disappear then re-appear later), elements that get moved around a lot or duplicated elements. They could all re-use the same cache.

## Conclusion

I hope you liked this deep dive. I really like the cleverness of this technique and its implications. Despite its difficulty to get right, this API is one that you can use without any thought about performance and memory usage—unlike the versions I proposed to some extent—which I really appreciate.

Thanks to [Simon Lydell](https://github.com/lydell/) for reviewing the draft and suggesting improvements.