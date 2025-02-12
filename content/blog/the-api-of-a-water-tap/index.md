---
title: The API of a water tap
content/blog/the-api-of-a-water-tap/index.md
published: "2019-01-02"
---

Let's say we wanted to represent a water tap. This tap will have two knobs, one to control cold water output and another one for warm water. To keep things relatively simple, each knob will be either closed or open all the way.

If I had to represent this tap, I would write this function (over-simplified with regards to the output):

```javascript
// Definition

function tap(coldKnobOpen, warmKnobOpen) {
  if (coldKnobOpen && warmKnobOpen) {
    // Both knobs are open
    return 'lukewarm water'
  }
  if (coldKnobOpen) {
    // Only the cold knob is open
    return 'cold water'
  }
  if (warmKnobOpen) {
    // Only the warm knob is open
    return 'warm water'
  }
  // Both knobs are closed
  return 'no water'
}

// Usage

tap(false, false) // With both knobs closed
// 'no water'

tap(false, true) // Opening the warm water knob
// 'warm water'

tap(true, true) // Opening both knobs
// 'lukewarm water'

tap(true, false) // Opening the cold knob
// 'cold water'
```

What happens when you open the cold knob all the way? You'd expect to get cold water, and with this function, that is what you would get. But in the physical world, sometimes when I want a glass of water, I open the cold knob and surprisingly get warm water, which is never a nice surprise as I find drinking warm water really unpleasant.

How does that happen? Well, someone used the tap before me and made warm water flow out of it, which then remained in the pipe until I used the tap and released the water. It turns out the tap holds an internal state - the temperature of the water in the pipe - which impacts the output. So it should look more like the following (this time, it's also over-simplified with regards to flow rate):

```javascript
// Definition

function createTap() {
  let waterInThePipe = 'cold water'

  return function(coldKnobOpen, warmKnobOpen) {
    // Both knobs are closed
    if (!coldKnobOpen && !warmKnobOpen) {
      return 'no water'
    }
    const output = waterInThePipe
    waterInThePipe = newWater(coldKnobOpen, warmKnobOpen)
    return output
  }
}

function newWater(coldKnobOpen, warmKnobOpen) {
  if (coldKnobOpen && warmKnobOpen) {
    // Both knobs are open
    return 'lukewarm water'
  }
  if (coldKnobOpen) {
    // Only the cold knob is open
    return 'cold water'
  }
  // Only the warm knob is open
  return 'warm water'
}

// Usage

const tap = createTap()

tap(false, false) // With both knobs closed
// 'no water'

tap(true, false) // Opening the cold water knob
// 'cold water'

tap(false, true) // Opening the warm water knob
// 'cold water'

tap(true, true) // Opening both knobs
// 'warm water'

tap(true, false) // Opening the cold water knob
// 'lukewarm water'
```

This is more accurate and allows me to reproduce what happened to me when I accidentally drank warm water. But I don't like this API for several reasons:

1. We can't predict the result of a single call to `tap`. If I call `tap(false, true)`, maybe I'll get warm water, but maybe I won't, and I have to test the result in the code. With a physical tap, I usually have to put my finger under the tap and get it wet in order to know the water's temperature.
2. If I want to be sure of what I'm getting, I need to call `tap` twice, like `tap(false, true); const result = tap(false, true)`, disregarding the first one. With a physical tap, I can, and often have to, let the water flow for a while, which is a waste of water.
3. I need to call the API to know the temperature in the pipe. With a physical tap, I have to open a knob and let water flow to determine the temperature, which again is a waste of water. I'm not sure that information is interesting though, unless it helps me know what output to expect next.
4. If I don't look at the documentation, should any even exist, there is nothing telling me that I should expect different results when calling the API with the same inputs, which I always find surprising.
5. There is a one call delay between what I request and what I get, which is not explained in the API. Maybe we could rename the functions and/or the format of the output to make that clearer.

For these reasons, I don't like this API and I don't like my physical tap. Have you ever seen documentation for a water tap? I'm sure it exists somewhere, but I haven't seen one.

One way we could make this better, is to make the implicit state explicit.

```javascript
// Definition
const initialWaterInPipe = 'cold water'

function tap(coldKnobOpen, warmKnobOpen, waterInPipe) {
  // Both knobs are closed
  if (!coldKnobOpen && !warmKnobOpen) {
    return {
      water: 'no water',
      waterInPipe: waterInPipe,
    }
  }
  return {
    water: waterInPipe,
    waterInPipe: newWater(coldKnobOpen, warmKnobOpen),
  }
}

function newWater(coldKnobOpen, warmKnobOpen) {
  if (coldKnobOpen && warmKnobOpen) {
    // Both knobs are open
    return 'lukewarm water'
  }
  if (coldKnobOpen) {
    // Only the cold knob is open
    return 'cold water'
  }
  // Only the warm knob is open
  return 'warm water'
}

// Usage

let output = tap(false, false, initialWaterInPipe) // With both knobs closed
// output.water === 'no water'

output = tap(true, false, output) // Opening the cold water knob
// output.water === 'cold water'

output = tap(false, true, output.waterInPipe) // Opening the warm water knob
// output.water === 'cold water'

output = tap(true, true, output.waterInPipe) // Opening both knobs
// output.water === 'warm water'

output = tap(true, false, output.waterInPipe) // Opening the cold water knob
// output.water === 'lukewarm water'
```

How does this compare to the problems I mentioned before?

1. _We can't predict the result of a single call to `tap`_: Since we now all the inputs, we now can predict the output reliably.
2. _If I want to be sure of what I'm getting, I need to call `tap` twice_: I can now predict the output, so this is now irrelevant. I might still have to let the water flow in order to get warm water out of a previously cold tap though.
3. _I need to call the API to know the temperature in the pipe_: I still don't know if this is useful, but I now have that information.
4. _There is nothing telling me that I should expect different results when calling the API with the same inputs_: Now you'll get the same results with the same inputs.
5. _There is a one call delay between what I request and what I get_: It is probably debatable, but if the name of the parameter is clear enough in the documentation or source code, I think it can be understood why I might still have to let the water flow in order to get warm water out of a previously cold tap.

Obviously, there are a few trade-offs.

1. The function output is more complex, and we have to store/keep the `waterInPipe` value somewhere. In my opinion, the impact on your code is not that big and probably worth the trade. We would have needed to store the `tap` function with the previous implementation too.
2. It is possible to cheat the API and pass it any value, like having a warm tap at the beginning. Depending on your use-case, this can actually be good to have. If you reload a saved state, you may want to be able to restore the tap as it was before, and not have it be cold again. If you don't, there are ways that this can be made much harder or impossible, depending on the tools/language you use.
3. It is possible to "cheat" and pass a not up-to-date `waterInPipe` value.

## My favorite API

Of the APIs written here, my favorite is, by far, the first one, the one without state. I would be much happier if my tap poured warm water directly when what I want is warm water. If you can design your system to be without state, please do so.

If not, because the system you're handling really needs to hold some state, make it explicit, even if it's not understandable by the user. Just knowing there is a state removes surprises, like warm water in my glass.
