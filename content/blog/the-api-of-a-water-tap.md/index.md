---
title: The API of a water tap
date: '2019-01-02T00:00:00.000Z'
---

Let's say we wanted to define an set of functions to control a water tap. This tap will have two knobs, one to control cold water output and another one for warm water, each being either closed or open all the way, just to make things a bit simpler.

Imagine a water tap (or a faucet, depending on where you come from), with two handles, one for cold water and one for warm water, and the handles are either closed or open all the way (just to simplify things). It resembles a function, in the sense that there are inputs to the system (represented by the states of the handles), and an output (represented by the presence of the water, and its temperature).

If I had to represent this system, I could represent this using the following function (over-simplified, especially with regards to the output):

```javascript
// Definition

function tap(coldHandleOpen, warmHandleOpen) {
  if (coldHandleOpen && warmHandleOpen) {
    // Both handles are open
    return 'lukewarm water'
  }
  if (coldHandleOpen) {
    // Only the cold handle is open
    return 'cold water'
  }
  if (warmHandleOpen) {
    // Only the warm handle is open
    return 'warm water'
  }
  // Both handles are closed
  return 'no water'
}

// Usage

tap(false, true) // Opening the warm water handle
// 'warm water'

tap(true, true) // Opening both handles
// 'lukewarm water'

tap(true, false) // Opening the cold handle
// 'cold water'
```

I'll now ask you: what happens when you have such as tap, and open the cold handle all the way? You'd expect to get cold water.
Well, sometimes when I want a glass of water, I open the cold handle and surprisingly get warm water, which is never a nice surprise as I find drinking warm water really unpleasant. How does that happen? Well, someone used the tap before me and made warm water flow from it, which then remained in the pipe until I used the tap and released the water.

It turns out the tap holds an internal state - the temperate of the water in the pipe - which impacts the output, so maybe it should look more like the following (this time, it's also over-simplified with regards to flow rate):

```javascript
// Definition

function createTap() {
  let waterInThePipe = 'cold water'

  return {
    tap: function(coldHandleOpen, warmHandleOpen) {
      // If both handles are closed, don't change the
      if (!coldHandleOpen && !warmHandleOpen) {
        return 'no water'
      }
      const output = waterInThePipe
      waterInThePipe = newWater(coldHandleOpen, warmHandleOpen)
      return output
    },
  }
}

function newWater(coldHandleOpen, warmHandleOpen) {
  if (coldHandleOpen && warmHandleOpen) {
    // Both handles are open
    return 'lukewarm water'
  }
  if (coldHandleOpen) {
    // Only the cold handle is open
    return 'cold water'
  }
  // Only the warm handle is open
  return 'warm water'
}

// Usage

const { tap } = createTap()

tap(true, false) // Opening the cold water handle
// 'cold water'

tap(false, true) // Opening the warm water handle
// 'cold water'

tap(true, true) // Opening both handles
// 'warm water'

tap(true, false) // Opening the cold water handle
// 'lukewarm water'
```

This is more accurate and allows me to reproduce what happened to me when brushing my teeth. But I don't like this API for several reasons:

1. We can't predict the result of a single call to `tap`. If I call `tap(false, true)`, maybe I'll get warm water, but maybe I won't, and I have to test the result in the code. With a physical tap, I usually have to put my finger under the tap and get it wet in order to know the temperature.
2. If I want to be sure of what I'm getting, I need to call `tap` twice, like `tap(false, true); const result = tap(false, true)`, disregarding the first one. With a physical tap, I can, and often have to, let the water flow for a while, which is a waste of water.
3. I need to call the API to know the temperature in the pipe. With a physical tap, I have to open a handle and let water flow to determine the temperature, which again is a waste of water. I'm not sure that information is interesting though, unless it helps me know what output to expect next.
4. If I don't look at the documentation, should any even exist, there is nothing telling me that I should expect different results when calling the API with the same inputs, which I always find surprising.
5. There is a one call delay between what I request and what I get, which is not explained in the API. Maybe we could rename the functions and/or the format of the output to make that clearer.

For these reasons, I don't like this API and I don't like my physical tap. Have you ever seen documentation for a water tap? I'm sure it exists somewhere, but I haven't seen one.

One way we could make this better, is to make the implicit state explicit.

```javascript
// Definition
const initialWaterInPipe = 'cold water'

function tap(coldHandleOpen, warmHandleOpen, waterInPipe) {
  // If both handles are closed, don't change the
  if (!coldHandleOpen && !warmHandleOpen) {
    return {
      water: 'no water',
      waterInPipe: waterInPipe,
    }
  }
  return {
    water: waterInPipe,
    waterInPipe: newWater(coldHandleOpen, warmHandleOpen),
  }
}

function newWater(coldHandleOpen, warmHandleOpen) {
  if (coldHandleOpen && warmHandleOpen) {
    // Both handles are open
    return 'lukewarm water'
  }
  if (coldHandleOpen) {
    // Only the cold handle is open
    return 'cold water'
  }
  // Only the warm handle is open
  return 'warm water'
}

// Usage

let output = tap(true, false, initialWaterInPipe) // Opening the cold water handle
// output.water === 'cold water'

output = tap(false, true, output.waterInPipe) // Opening the warm water handle
// output.water === 'cold water'

output = tap(true, true, output.waterInPipe) // Opening both handles
// output.water === 'warm water'

output = tap(true, false, output.waterInPipe) // Opening the cold water handle
// output.water === 'lukewarm water'
```

How does this compare to the problems I mentioned before?

1. _We can't predict the result of a single call to `tap`_: Since we now all the inputs, we now can predict the output reliably.
2. _If I want to be sure of what I'm getting, I need to call `tap` twice_: I can now predict the output, so this is now irrelevant. Though I might still have to let the water flow in order to get warm water from a previously cold tap.
3. _I need to call the API to know the temperature in the pipe_: I still don't know if this is useful, but I now have that information.
4. _there is nothing telling me that I should expect different results when calling the API with the same inputs_: Now you'll get the same results with the same input, which I always find surprising.
5. _There is a one call delay between what I request and what I get_: It is probably debatable, but if the name of the parameter is clear enough in the documentation or source code, I think it can be understood why I might still have to let the water flow in order to get warm water from a previously cold tap.

Obviously, there are a few trade-offs:

1. The function output is more complex, and we have to store/keep the `waterInPipe` value somewhere. In my opinion, the impact on your code is not that big and probably worth the trade.
2. It is possible to cheat the API and pass it any value, like having a warm tap at the beginning. Depending on your use-case, this can actually be good to have. If you reload a saved state, you may want to be able to restore the tap as it was before, and not have it be cold again. If you don't, there are ways that this can be made much harder or impossible, depending on the tools/language you use.
3. It is possible to cheat and pass a not up-to-date "previous" value.

## My favorite API

Of the APIs written here, my favorite, by far, is the first one. The one without state. If you can design a system without a state, be it explicit or implicit, please do so. I would be much happier if my tap poured warm water directly when what I want is warm water.

If, for some reason, you do need state, make it explicit, even if it's not understandable by the user, just knowing there is one would remove surprises, like warm water in my glass.
