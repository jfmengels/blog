---
title: Failing at optimizing record updates
date: '2021-06-01T12:00:00.000Z'
---

Inspired by Robin Hansen's great series of posts about how to (sometimes failing to) [improve Elm performance](https://blogg.bekk.no/successes-and-failures-in-optimizing-elms-runtime-performance-c8dc88f4e623),
I thought it would be valuable to go through a failure of my own. Hopefully that will save people some time from exploring the same thing, or maybe someone will have a brighter idea. 

## The problem

I was looking into whether we could improve a pattern that we often see in The Elm Architecture, that deals with nested
module update and nested records.

Say we have a module `SubModule` which has this `update` function:

```elm
-- SubModule.elm
type alias Model =
    { -- ...
    }

update : Msg -> Model -> Model
update msg model =
  case msg of
    SomethingHappened ->
        { model | something = happened }

    NothingHappened ->
        model
```

And a `Main` module which uses `SubModule`

```elm
-- Main.elm
import SubModule

type alias Model =
    { subModule : SubModule.Model
    -- ...
    }

type Msg
  = SubModuleMsg SubModule.Msg
  | OtherMsg

update : Msg -> Model -> Model
update msg model =
  case msg of
    SubModuleMsg subMsg ->
        { model | subModule = SubModule.update subMsg model.subModule }

    OtherMsg ->
        -- ...
```

In the case where `SubModuleMsg NothingHappened` is triggered, `SubModule.update` returns an unaltered `Model`, yet we create a new reference for `Main.Model` because we re-assign the field.

The value for `Main.Model` would be the exact same, but it would have a new reference. In JavaScript, which Elm compiles
down to, when you do `===`, it returns true if the values are primitives have the same value, or if they're
objects/arrays and they point to the same value in memory. `a === a` would always be `true`, regardless of the value for
the variable `a`, but `[] === []` would be `false` because each `[]` would be allocated to a new position in memory.

Why does it matter that the `Main` model has a new reference? It usually doesn't, but when the reference doesn't change,
then Elm can do some neat optimizations like avoiding recomputing parts of the view when [using Html.Lazy](https://guide.elm-lang.org/optimization/lazy.html).

Had we wrapped `Main.view` in a way that would make it lazy, then that optimization would not kick in after `SubModuleMsg NothingHappened` gets triggered because of the new reference.

Because the reference to `Main.Model` has changed, `Main.view` will cause to get called again and any lazy function that depends on `Main.Model` will be recomputed again.

----


Maybe option A isn't too bad?

Option A optimizes for when the references will be different, which will happen most of the time.

Option B optimizes for when the references will be the same, which will rarely be the case.

Option C is the fastest, but cause the functions that use it to be de-optimized.