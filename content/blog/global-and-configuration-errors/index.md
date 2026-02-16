---
title: Global and configuration errors
slug: global-and-configuration-errors
published: "2021-04-06"
---

I just released version `2.4.0` of the `jfmengels/elm-review`, and `2.5.0` of the `elm-review` CLI. The release of the Elm package contains some missing features that could be considered core to `elm-review`, and that will be useful to people who writing review rules. The focus has mostly been on reporting errors.

tl;dr:
- [You can now report global errors](#global-errors)
- [and also configuration errors](#configuration-errors)
- [There are now pre-built dependencies available for tests](#test-dependencies)
- [You can provide fixes for elm.json](#automatic-fixes-for-elmjson)
- And some more...

## Foreword

Starting from v2.5.0, the CLI will require `jfmengels/elm-review` v2.4.0, which in turn also silently requires needs the latest version of the CLI, so **you should update both of these at the same time**.

To upgrade:
```bash
npm install elm-review@latest

cd review/
npx elm-json upgrade
```

## Global errors

In `elm-review`, all errors are tied to a location in the project, and more specifically to a file (an Elm module, `elm.json` or the `README`) and a position in the file (where you'd see the squiggly lines). Pointing to a specific location in a project is really useful for users to quickly go to the indicated location and fix the issue.

![](/images/global-and-configuration-errors/regular-error.png)

Unfortunately it does not always make sense to point to a specific location. For instance, what if a rule is expecting a module or a function to exist somewhere in the project (a `main` function for instance, or something that the user provides as part of the configuration) and that can't be found? Well you can't point the user to the `main` saying that it doesn't exist. There's no specific location to point to.

In [Safe unsafe operations in Elm](/safe-unsafe-operations-in-elm#making-sure-the-target-function-exists) we created a rule that takes as part of its configuration the name and module name of a function, which we would handle differently. In that article, we mentioned the problem that if the function could not be found, we would create an error for the `elm.json` file, because that's the best we could do, though it was still kind of confusing.

To resolve this problem, `2.4.0` of the package adds a way to create [**global errors**](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#globalError), which are by definition not tied to a location in the project.

```elm
error : String -> Error scope
error moduleName =
    Rule.globalError
        { message = "Could not find module " ++ moduleName
        , details =
            [ "You mentioned the module " ++ moduleName ++ " in the configuration of this rule, but I could not find it."
            , "This likely means you misconfigured the rule or the configuration has become out of date with recent changes in your project."
            ]
        }
```

![Global error saying: The threshold needs to be strictly positive. A threshold less than 1 means that you can't use case expressions at all, which is not the intent of this rule. Please change the threshold to a higher value.](/images/global-and-configuration-errors/global-error.png)



Global errors are easy to create, but they are also less helpful to the users, so they should be used only when other errors are inappropriate. They don't allow for automatic fixes either.

Testing rules is also part of the experience of writing review rules, that's why there are [new functions](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test#expectGlobalErrors) to assert that the rule behaves as expected.

## Configuration errors

In addition to global errors, we are introducing `configuration errors`. These are errors that will be the result of parsing or validating the arguments of a rule, and noticing a problem with those.

Since the configuration is written in Elm, it gives a good experience to the user when the compiler is the one reporting configuration errors, which rule authors can do through custom types for instance.

That said, it is not possible or practical to validate everything only with that: Positive integers, strings with certain shapes, non-empty sets/dicts, lists without duplicate items, etc.

For instance, imagine you want to have a rule that forbids nested case expressions up to a certain threshold (not saying I'd want this, but it's a fine example). If the threshold is not something that you think is reasonable, you can report a configuration error like this:

```elm
rule : Int -> Rule
rule threshold =
  if threshold >= 1 then
    Rule.newModuleRuleSchema "NoNestedCaseExpressions" ()
      |> Rule.withSimpleExpressionVisitor (expressionVisitor threshold)
      |> Rule.fromModuleRuleSchema

  else
    Rule.configurationError "NoNestedCaseExpressions"
      { message = "The threshold needs to be strictly positive"
      , details =
        [ "A threshold less than 1 means that you can't use case expressions at all, which is not the intent of this rule."
        , "Please change the threshold to a higher value."
        ]
      }
```

![Condiguration error saying: The threshold needs to be strictly positive. A threshold less than 1 means that you can't use case expressions at all, which is not the intent of this rule. Please change the threshold to a higher value.](/images/global-and-configuration-errors/configuration-error.png)


Without a configuration error but with global errors, authors would have to create a dummy rule, with a visitor and that reports a single error, or add a lot of conditionals in every visitor.

In practice, a configuration error is almost that: a dummy rule that reports a single error. With the side-benefit that the `elm-review` CLI will abort early and report the configuration errors before reviewing the entire project. So the feedback is a lot faster, which will be useful on large projects.

Again, there are dedicated testing tools to assert that the rule [reports a configuration error](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test#expectGlobalErrors).

## Test dependencies

While we're on the subject of test dependencies: a common complaint from rule authors was that it was hard/tedious to create tests where the project had dependencies, even if the dependency is something as core as `elm/core` (pun barely intended).

That's why I'm introducing a few new functions to help with that. I added 4 pre-built dependencies to the package in a new [`Review.Test.Dependencies`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test-Dependencies) module: The three packages that contains operators (`elm/core`, `elm/parser` and `elm/url`) and `elm/html` (which I thought could be useful). If you need to test with a different dependency, I added instructions and a script to generate Elm code corresponding to the dependency.

I also added [`projectWithElmCore`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test-Dependencies#projectWithElmCore) which is just like the existing `Project.new` but with `elm/core` already added. Also, `elm/core` is now added **by default** to all tests (unless you use `runWithProjectData`).

With these changes, I could remove almost all custom dependencies I set up in my own tests, so I think this will be nice quality of life improvement for everyone else.

## Automatic fixes for elm.json

You may know that `elm-review` looks at `elm.json` and allows reporting errors for it if you've ever seen a report saying you had unused dependencies.

Even though it was possible to report errors for it, it wasn't possible to provide fixes for it. Using [`Review.Rule.errorForElmJsonWithFix`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#errorForElmJsonWithFix), it is now.

One thing we'd like to use it for is for automatically removing unused dependencies, which would look something like this (work in progress):

![](/images/global-and-configuration-errors/unused-dependency-fix.png)

## ignore-dirs and ignore-files

The CLI has two new flags, `--ignore-dirs` and `--ignore-files`. These will be especially useful when running with `--template`.

In your local review configuration, you may have ignored some directories or files, for instance the directory for generated code. When you use `--template` (or `--config`), you'll use a configuration that will not have those exceptions.

To remedy that, you can call `elm-review` with those flags, that will add additional directories/files to be ignored.

## Progression status for --fix-all

When you run `elm-review --fix-all` and there are a lot of errors, it can take quite a while to finish and it may look like `elm-review` will be hanging or doing nothing.

When `elm-review` applies more than a certain number of fixes and to comfort the user in the idea that something is happening, it will display a message saying that it **is** doing work!

![I am applying fixes, I have applied X already, and I see about Z more!](/images/global-and-configuration-errors/progress-bar.gif)

I will probably tweak the message some more later, but at least knowing that something is happening makes for a much better experience.

## elm-bump script

`elm-review new-package` now comes with a `elm-bump` script. It's a nice utility to prepare for the next version. You can now publish a new version like this:

```bash
npm run elm-bump
git commit --all --message "1.0.1" # or whatever your version is
git push origin HEAD
```

And there you go! Once the tests in CI pass, a new version will be published. `elm-bump` runs tests, run `elm bump`, [update links in your documentation](https://package.elm-lang.org/packages/jfmengels/elm-review-documentation/latest/Documentation-ReadmeLinksPointToCurrentVersion), and update the `example/` configuration.

Not having this has caused me quite a few disappointments because I would often forget the last step. Thankfully, the problem gets caught in the CI, but this new workflow feels a lot nicer to me.

## Afterword

That's it for this release! As usual, there are other small changes or fixes, but I think these highlights were already a long enough read 😁

I hope you find this interesting! If you want to support me or `elm-review`, you can do so through [GitHub sponsors](https://github.com/sponsors/jfmengels/). Even using it, blogging about it or help me think through features is very much appreciated!