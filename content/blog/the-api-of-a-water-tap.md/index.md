---
title: The API of a water tap
date: '2019-01-01T00:00:00.000Z'
---

Let's say we wanted to define an set of functions to control a water tap (or a faucet, depending on where you come from). This tap will have two knobs, one to control cold water output and another one for warm water, each being either closed or open all the way, just to make things a bit simpler.

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
Well, sometimes when I go brush my teeth, I turn the cold handle and surprisingly get warm water, which I find pretty unpleasant. How does that happen? Well, someone used the tap before me and made warm water flow from it, which then remained in the pipe until I used the tap and released the water.

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
      waterInThePipe = waterTemperature(coldHandleOpen, warmHandleOpen)
      return output
    },
  }
}

function waterTemperature(coldHandleOpen, warmHandleOpen) {
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

- We don't know what we must expect of a single call to `tap`. If I call `tap(false, true)`, maybe I'll get warm water, but maybe I won't, and I have to test the result in the code. With a physical tap, I usually have to put my finger under the tap and get it wet in order to know the temperature.
- If I want to be sure of what I'm getting, I need to call the `tap` twice, like `tap(false, true); const result = tap(false, true)`, disregarding the first one. With a physical tap, I can, and often have to, let the water flow for a while, which is a waste of water.
- I need to call the API to know the temperature in the pipe. With a physical tap, I have to open a handle and let water flow to determine the temperature, which again is a waste of water. I'm not sure that information is interesting though, unless it helps me know what output to expect next.
- If I don't look at the documentation, should any even exist, there is nothing telling me that I should expect different results when calling the API with the same results, which I always find surprising.
- There is a one call delay between what I request and what I get, which is not explained in the API. Maybe we could rename the functions (like `tap` to something along the lines of `changeTapInputs`, but something better) and/or the format of the output to make that clearer.

For these reasons, I don't like this API, and they are the same reasons why I get surprised when I get warm water when I wanted cold water with my physical tap. Have you ever seen a documentation of the workings of a water tap? I'm sure it exists somewhere, but I haven't.

So, how could we solve these pain points?

### Make implicit internal state explicit

### Give better names

### Simplify the function so there is no internal state

It turns out that taps are more complicated than the representation we have above. The temperature of the outgoing water is a factor of which knobs are opened, how long they have been open for, what kind of water last flowed and how long it's been since (in order to know what the temperature of the water currently in the pipe is)... and we're also skipping the flow rate which has an effect on multiple of these parameters.

#### To write

There are hidden inputs, which lead to surprise and confusion.
Give me a function without surprises: either that doesn't give me warm water as expected, or that explicits that it takes additional inputs.
Give me a simple API but with simple results, or a complicated one but that gives me proper results.
