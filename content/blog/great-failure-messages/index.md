---
title: Great compiler messages? Great test failure messages!
slug: great-failure-messages
published: "2021-02-18"
featuredImage: whitespace.png
---

If you've written a little bit of Elm code, I hope you've tried out [`elm-test`](https://package.elm-lang.org/packages/elm-explorations/test/latest/) which allows you to write and run tests for your Elm code (if you never heard of it, we talk about it [on the Elm Radio podcast](https://elm-radio.com/episode/elm-test)). A test looks like this:

```elm
import Test exposing (Test, test)
import Expect

myTest : Test
myTest =
    test "reverses a known string" <|
        \() ->
            "ABCDEFG"
                |> String.reverse
                |> Expect.equal "GFEDCBA"
```

The assertion, or "expectation" as is the naming choice of this library, is provided by the [`Expect`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect) module. It contains functions like [`equal`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect#equal), [`notEqual`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect#notEqual), [`lessThan`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect#lessThan), [`true`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect#true), etc.

These are often enough when the scope of the test is small. Sometimes (to me) it makes sense that the test is a bit more thorough and that it makes multiple assertions. To do that, you'll want to use [`Expect.all`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect#all):

```elm
test "generateRandomString" <|
    \() -> 
        startingSeed
            |> generateRandomString
            |> Expect.all
                [ \str -> Expect.greaterThan 16 (String.length str)
                , \str -> Expect.lessThan 64 (String.length str)
                , checkStringRandomness
                ]
```

What you may notice when you start making multiple assertions, is that the error message can be pretty bad.

```
↓ MyModule
✗ generateRandomString

    5
    ╷
    │ Expect.greaterThan
    ╵
    16
```

It's pretty unclear here which assertion failed. What is equal to 5 when it should have been greater than 16? Is that even how I should have read the error message? Which assertion failed? Was it `Expect.greaterThan 16 (String.length str)` or was it a check inside `checkStringRandomness`?


One reason that Elm developers love Elm is because of the great error messages that the compiler gives us.

![](/images/great-failure-message/compiler-error.png)

In comparison to that, the error message we got from `elm-test` was lacking in helpfulness. If we only had a single assertion that would be just fine, but when we multiply the assertions, that becomes a problem.

What if I told you your error messages could be just as great as the compiler's?


## Custom failure messages

So let's change this assertion to be much easier to understand, by rewriting the assertions using simple conditionals and the [`Expect.pass`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect#pass) and [`Expect.fail`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect#fail) functions.


```elm
test "generateRandomString" <|
    \() ->
        let
            startingSeed : Int
            startingSeed = 1234
        in
        startingSeed
            |> generateRandomString
            |> Expect.all
                [ shouldBeAtLeastCharactersLong16 startingSeed
                , \str -> Expect.lessThan 64 (String.length str)
                , checkStringRandomness
                ]

shouldBeAtLeastCharactersLong16 : Int -> String -> Expect.Expectation
shouldBeAtLeastCharactersLong16 startingSeed str =
    if String.length str > 16 then
        Expect.pass

    else
        Expect.fail ("""RANDOM STRING IS TOO SHORT

Using """ ++ String.fromInt startingSeed ++ """ as the seed, the randomly generated value was:

    """ ++ str ++ """

which is only """ ++ String.fromInt (String.length str) ++ """ characters long. I expected to find at least 16!""")
```


Let's go through what is happening here.

We make the assertion manually (`String.length str > 16`), and then based on whether that condition passed, call either `Expect.pass` or `Expect.fail`.
`Expect.pass` is an empty assertion that will always be considered as passing. You want to call this when you are in the happy path and you have nothing more to assert.
`Expect.fail` is an assertion that will always fail with the given error message.

This is a lot more verbose, sure, but look at the result of the same test with our new test code:

```
↓ MyModule
✗ generateRandomString

    RANDOM STRING IS TOO SHORT
    
    Using 1234 as the seed, the randomly generated value was:
    
        IUMPA
    
    which is only 5 characters long. I expected to find at least 16!
```

This is **much more helpful** for the developer who is working with the test, or even for a different developer who runs into this test failure. It's up to you to choose how you want to format the error message and what information you want to include.

### Alternative ways

You can achieve the same result without using `Expect.fail`.

A second way would be to use [`Expect.true`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect#true) / [`Expect.false`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect#false) since they also allow adding a custom failure message.


```elm
shouldBeAtLeastCharactersLong16 : Int -> String -> Expect.Expectation
shouldBeAtLeastCharactersLong16 startingSeed str =
    Expect.true
        ("""RANDOM STRING IS TOO SHORT

Using """ ++ String.fromInt startingSeed ++ """ as the seed, the randomly generated value was:

    """ ++ str ++ """

which is only """ ++ String.fromInt (String.length str) ++ """ characters long. I expected to find at least 16!""")
        (String.length str > 16)
```

A third way would be to use [`Expect.onFail`](https://package.elm-lang.org/packages/elm-explorations/test/latest/Expect#onFail):


```elm
shouldBeAtLeastCharactersLong16 : Int -> String -> Expect.Expectation
shouldBeAtLeastCharactersLong16 startingSeed str =
    String.length str
    	|> Expect.greaterThan 16
    	|> Expect.onFail ("""RANDOM STRING IS TOO SHORT

Using """ ++ String.fromInt startingSeed ++ """ as the seed, the randomly generated value was:

    """ ++ str ++ """

which is only """ ++ String.fromInt (String.length str) ++ """ characters long. I expected to find at least 16!""")
```

In practice, my personal preference goes to `Expect.pass` / `Expect.fail` because I find that conditionals read pretty nicely, partly because the condition is always at the top and because they are in a very familiar code construct. I also don't have to transform my code to use assertions where they don't fit well, for instance when doing pattern matches.

```elm
case result of
  Ok _ -> Expect.pass
  Err err -> Expect.fail (message err)
```

Also, performance-wise, I can compute the error message only when a problem has been noticed. The most common path (that should be optimized for) is when the tests pass, so I prefer to only add performance hits when necessary. In practice it is rarely a problem, but there are cases where computing a nice error message can be a bit expensive. Multiply that by the number of tests you have, and that can take some of your precious CI time a bit.

## Beautiful failure messages

`elm-test` supports adding colors to error messages using ANSI codes. Instead of doing `"TITLE -- bla bla"`, we can add special character sequences to add colors to our texts, like `"\u{001B}[31mTITLE\u{001B}[39m -- bla bla"`, and now a part of our message shows up in red!

We can add boldness to the number 16 if that's what we wanted to highlight by doing `"I expected to find at least \u{001B}[1m16\u{001B}[22m!"`.

![](/images/great-failure-message/with-colors.png)

You can find what is possible with ANSI codes [on the Internet](https://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html#8-colors).

I would advise using [helper functions like these](https://github.com/jfmengels/elm-review/blob/8fbd5723c90cc3d5fec483191e94f050c414f32a/src/Ansi.elm) because the code for the assertions becomes hard to read otherwise.

Note that `elm-test` always indents the failure message by 4 spaces. Just thought you might want to know that.

## Afterword

Some people advise to have one assertion per test. I agree that when that makes sense that can often yield a better test debugging experience. In those cases, using the default failure message is perfectly fine.

When the failure reason becomes cryptic and you notice it's often a debugging time sink, you might want to rethink how you wrote your tests, and potentially use this technique to make the failure clearer for the next person who will run into the same errors.

I came to know about this subject by working on the [testing module](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test) for [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/). `elm-review` provides a nice API which prevents you from making a mess out of your review rules. While that is enough to give a good experience for the one developing the rule, it is not enough to ensure a high quality for the user of the rule.

To help raise that, `elm-review` gives you access to test helpers to make testing rules a breeze and make sure that the rule does what you expect. Also, `elm-review` has opinions on what makes a good rule, in particular around the error message and the location of the error message, which I've written extensively about in the module's [design goals](https://github.com/jfmengels/elm-review/blob/master/documentation/design/test-module.md).

Its test helper runs a multitude of checks for you, and tries to report problems with clarity and enough context so that you can easily resolve the problem. My aim was to be as helpful in the testing phase as the Elm compiler is during the compilation phase. From feedback, I feel like I'm allowed to brag a little about the result 😊

Here is an example where I had to be fancy with colors to make a specific problem around whitespace easy to resolve.

![](/images/great-failure-message/whitespace.png)

You can go read [the file containing the possible error messages](https://github.com/jfmengels/elm-review/blob/5e2b633c5406a90677c8c5f06984053591aa9c32/src/Review/Test/FailureMessage.elm) or the [test module](https://github.com/jfmengels/elm-review/blob/5e2b633c5406a90677c8c5f06984053591aa9c32/src/Review/Test.elm) itself if you're curious.

I believe that when you're working with a framework/platform tool like `elm-review`, you should have the means to test your code extensively. As a library author, it's not a small task, but it feels so worth it in my experience.
