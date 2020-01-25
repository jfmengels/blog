---
title: Learning from Elm: Opaque types in JavaScript
date: '2019-12-16T00:00:00.000Z'
redirect_from:
  - /learning-from-elm-opaque-types-in-javascript/
---

One of my favorite features in Elm are opaque types. Recently, I had to write a lot of JavaScript, and

NOTE: https://codemix.com/opaque-types-in-javascript/
You can have them in TypeScript too, do note that this is for plain ES2015 JavaScript.

## What are opaque types?

Opaque types are a way to hide the implementation details of a data structure, defined inside of a file, from the other files of the project or library.
The key traits are:

- No other files can access the internals of the data structure.
- What other files can do with the data is defined by the API the module comes with

TODO talk about free re-modeling the internals

## An example

Imagine the following example: You are modeling a user on a video streaming platform, and you wish to store some of the user's personal information, along with the list of videos they watched.

```js
const exampleUser = {
  name: 'Jeroen Engels',
  watchedVideos: [123, 234, 345],
}
```

Often, you have some constraints or expectations about the data you are working with, though they are often not documented. Luckily for us, someone documented some of these somewhere in the code.

```js
// DO NOT delete elements from `watchedVideos`!
// They will be synchronized with the server, which crashes when you remove
// elements from the array.
// See the issue at https://github.com/ABC/XYZ/issues/789 for more information.
//
// Also, make sure to not add the same id twice, otherwise the video shows up
// twice in the user's view history.
```

You can't un-watch a video, so it makes sense not to delete them anyway.

Now, somewhere in the codebase, potentially far away from the comment above, there may be some code which alters the data we are working with in a way that goes against these constraints. Like forgetting to check whether the id is in the array before adding it.

```js
// some/where/else.js
user.watchedVideos.push(345)
// Oops, that id is now in the array twice
console.log(user.watchedVideos)
// => [123, 234, 345, 345]
```

How would you go about to make sure you can't have the same id twice, and that you can't remove an id?

This is a question that Elm developers tend to focus on: creating guarantees (an id can not be removed), usually through constraints (making it impossible to remove an id). One of the common techniques for this are opaque types.

## Opaque types in Elm

In Elm, developers tend to focus a lot on ways to create guarantees, usually through constraints, to avoid entering pitfalls like the one we described before. One of the common techniques for this are opaque types.

Here is how we model our user:

```elm
import WatchedVideos

exampleUser = {
  name = "Jeroen Engels",
  watchedVideos = WatchedVideos.fromList [123, 234, 345]
}
```

(technically, the above is a list, not an array, but I try to make the article easy to read to those familiar with JavaScript but not Elm)

```elm
-- WatchedVideos.elm

-- The following line explicits what functions (and types) are exported and
-- available to other files, similar to `export` in JavaScript.
module WatchedVideos exposing (WatchedVideos, fromList, add, ids)


type WatchedVideos = WatchedVideosConstructor (List Int)


{-| Function that creates a new set of watched videos, starting from the -}
fromList list =
  WatchedVideosConstructor (removeDuplicates list)


{-| Function that adds a new id of all the watched videos -}
add videoId (WatchedVideosConstructor list) =
  if List.member videoId list then
    -- If the id is already in the list, don't add it
    WatchedVideosConstructor list
  else
    -- The syntax `videoId :: list` means that videoId is added to `list`
    WatchedVideosConstructor (videoId :: list)


{-| Function that retrieves the ids of all the watched videos -}
ids (WatchedVideosConstructor list) =
  list


{-| Function that removes duplicates from a list. -}
removeDuplicates list =
  ... -- The implementation is not important here.
```

One of the great benefits

- Surface area
- Can control the operations on the data structure
- Can change the internals without breaking the API.

## How to do that in Elm?

## Without opaque types

What I often see, is that functions

```js
```

Since

## Opaque types in JavaScript

Several solutions:

- https://medium.com/@sayes2x/hiding-variables-and-closure-in-javascript-c6d1cafbd037

```js
function counter() {
  let count = 0

  return {
    increment: x => {
      count = count + x
    },
    decrement: x => {
      count = count - x
    },
    value: () => count,
  }
}
```

- Simple, but stateful, so you can't copy the data

Using closure,

```js
function counter(count) {
  return {
    increment: x => counter(count + x),
    decrement: x => counter(count - x),
    value: () => count,
  }
}
```

Immutable, but this might be a bit expensive as the functions will be recreated at every operation. Also, . If performance is not an issue, then this pattern might be good enough for you.

- https://medium.com/@sayes2x/hiding-variables-and-closure-in-javascript-c6d1cafbd037
  - Simple, but stateful, so you can't copy the data

Here is the basic

```js
const symbol = Symbol('whatever')

//
```

By limiting the API you offer, you have control over the guarantees you wish to give to your data. Once you make sure that all the exposed functions respect those guarantees at all times, they will apply to the rest of the codebase, at least for this piece of data.

Do you want your data to respect some constraints about its values?

```js
function create(name, age) {
  if (age < 0) {
    // Don't create a real value when the data is incorrect
    // Depending on what you prefer, you can also throw an error or set a "default" value
    return null
  }
  if (name.length === 0) {
    return null
  }

  return {
    [symbol]: {
      name,
      age,
    },
  }
}

function setAge(newAge, age) {
  if (age < 0) {
    // Don't create a real value when the data is incorrect
    // Depending on what you prefer, you can also throw an error or set a "default" value
    return null
  }
  if (name.length === 0) {
    return null
  }

  return {
    [symbol]: {
      name,
      age,
    },
  }
}
```

## Making the API of the module explicit

Because other modules will only be able to use the exposed API, and not the underlying data structure, I suggest putting a lot of extra care on the exposed API.

Here is what I try to do.

1. Using Elm, I have grown pretty attached to exposing everything

```js
// Module file

// Export everything at the top of your file
export default {
  // BUILD
  create,

  // ACCESS
  name,
  age,

  // MODIFY
  setAge,
}

// Client file
import User from './User'

const user = User.create('Jeroen', 'Engels')
console.log(User.age(user))
const userWithOtherAge = console.log(User.age(user))
```

Because you've now imported `User` the way above, you'll only have to search for `User.setAge` to see where it is used.

2. Name and document your functions well

## Limits

Technically, It is possible to access the contents of our object using [`Object.getOwnPropertySymbols()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/getOwnPropertySymbols). For this technique to be used as intended with all its benefits, I suggest not using it.
If you see your colleagues using it, I suggest
I suggest not hope that this will only be done for debugging

## Internet Explorer support

Internet Explorer doesn't support `Symbol`, but for this technique, a very simple polyfill is needed.

```js
window.Symbol = window.Symbol || a => `a_${Math.random()}`;
```

Basically, if `Symbol` already exists, leave it as it is. For this technique, this is the only thing we need. The idea is basically to prevent the developers on our team from wanting to access the fields of our opaque type manually. If we get rid of that habit, then the symbol check could potentially be removed, but it's still a nice safe-guard to have. The `Math.random()` part is not necessary, the polyfill could have been `window.Symbol = window.Symbol || a`, but the randomness makes `Symbol('a') === Symbol('a')` false in practice, which is the primary thing we want to get out of `Symbol`.

Word of warning: if you use libraries, they may rely on `Symbol` and may bring their own polyfill. You might want to check whether they add their own `Symbol` polyfill, as you don't want them to break because you prevented their polyfill to be applied when they needed less basic uses of `Symbol`.

Thank you for reading!
