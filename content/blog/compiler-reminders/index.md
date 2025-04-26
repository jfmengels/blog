---
title: Compiler reminders
slug: compiler-reminders
published: "2025-04-27"
---

Even though it is rarely called that way, compiler reminders are a very useful feature in Elm, one that is core to making Elm code maintainable.

The idea is that whenever a change in the code would lead to other code needing to be modified at the same time, we'd get a compiler error reminding us that we need to make some kind of change.

We like this so much in Elm that a common task for beginners is to take the basic [Elm counter example](https://ellie-app.com/new) and add a button to reset the counter to 0. This usually goes well (depending on how much the different syntax bothers them) because the compiler will tell them what the next step is.

(I'll go through it so if you want to do it yourself, pause now and [have a go at it](https://ellie-app.com/new))

1. We add a button: `button [ onClick Reset ] [ text "Reset" ]` somewhere in the `view`.

```ansi
[36m-- NAMING ERROR --------------------------------------------------- src/Main.elm[0m

I cannot find a `Reset` variant:

38|         , button [ onClick Reset ] [ text "Reset" ]
                               [91m^^^^^[0m
```

2. We get a compiler error saying that the `Reset` value is unknown, so we add it to the list of variants for the `Msg` type.

```elm
type Msg
    = Increment
    | Decrement
    | Reset
```

```ansi
[36m-- MISSING PATTERNS ----------------------------------------------- src/Main.elm[0m

This `case` does not have branches for all possibilities:

25|[91m>[0m    case msg of
26|[91m>[0m        Increment ->
27|[91m>[0m            { model | count = model.count + 1 }
28|[91m>[0m
29|[91m>[0m        Decrement ->
30|[91m>[0m            { model | count = model.count - 1 }

Missing possibilities include:

    [33mReset[0m

I would have to crash if I saw one of those. Add branches for them!
```

3. We get a compiler error saying that the `update` function does not have a branch for the `Reset` variant (because of the compiler's exhaustiveness checking), so we add the branch where the counter is set to 0.

```elm
update : Msg -> Model -> Model
update msg model =
    case msg of
        -- ...other branches...

        Reset ->
            { model | count = 0 }
```

And the feature is then complete!

We added one piece of code, got 2 compiler errors that required more changes—and more or less indicated how to resolve the issue—and once we did, everything worked as expected.

In the Elm community (among others) we often refer to this as following the compiler (or compiler driven development), and the end result as "if it compiles, it works".

Some folks even made an [workshop to teach Elm](https://github.com/jgrenat/elm-compiler-driven-development) (in French) based on exercises where all you need to do is to follow the compiler error messages.

Type and exhaustiveness checks are the main drivers behind this example (there are others). You could therefore say that compiler reminders goes hand in hand with type safety and statically typed languages, but that's not necessarily the case.

Type safety is when the compiler confirms whether we have correctly connected everything in a way that makes sense and avoids type errors. Compiler reminders is a technique on top of that, where we ensure that some changes will force us to make additional changes.

For instance, say that instead of handling all cases explicitly we used a default/wildcard branch:

```elm
update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            { model | count = model.count + 1 }

     -- was previously
     -- Decrement ->
        _ ->
            { model | count = model.count - 1 }
```

then we wouldn't have the second reminder to handle the `Reset` variant, because we are (somewhat incorrectly) already handling it.

This is why we often advise Elm developers to list out all the branches in `case` expressions rather than using a wildcard. Even if it sometimes feels tedious, it increases the number of cases where making a change leads to getting compiler reminders.

And compiler reminders are in my opinion a very important tool for a maintainable codebase.

## Non-compiler reminders

The concept of "reminders" is not limited to a compiler or a type checker.

For instance, if we introduce a variable in the code, then a linter will tell us it's unused, reminding us to use it (don't tell me you have never added a variable and forgotten to use it).

Similarly, when removing the last usage of a variable, the same linter will tell us to remove the variable as well. We get a cleanup reminder.

If we can define our own linting rules, then we can create custom linter reminders. For example, let's say we have some value meant to hold all different variants of a type:

```elm
type UserKind = User | Admin

allUserKinds : List UserKind
allUserKinds =
  [ User, Admin ]
```

Say that we add a new type of user such as `Guest`, we would like to not be able to forget adding the value in `allUserTypes` (and that could be us or a colleague). At work we have a linter rule to remind us to add it. Not a compiler reminder, but the same idea and kind of benefit.

Different tools can yield different kinds of reminders (or [guarantees](/constraints-and-guarantees)). Even writing a test can be used to create one.

---

Reminders are important because they don't let us forget to do necessary tasks, but also because they give the same information to colleagues who may not have been taught (and may never be taught) some rules of the codebase.

Highly maintainable codebases use reminders a lot. We just need to find the most appropriate kind of reminder for each problem.