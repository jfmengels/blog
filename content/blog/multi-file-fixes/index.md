---
title: Multi-files fixes
slug: multi-file-fixes
published: "2025-02-11"
---

Today marks the release of a new important version for `elm-review`.
The major highlight is automatic fixes, as they can now edit multiple files at the same time, and even remove files.

## Upgrading

The new versions are `2.15.0` for the [`jfmengels/elm-review` Elm package](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/) and `2.13.0` for the [`node-elm-review` `npm` CLI](https://www.npmjs.com/package/elm-review).

I recommend upgrading the Elm package dependencies using the `elm-json` tool (which doesn't require you installing it). `jfmengels/elm-review-unused` should get upgraded to `1.2.4`  as well, with the changes mentioned further below.

```sh
npm install --save-dev elm-review
cd review
npx elm-json upgrade
```

## Fixing multiple files

Static code analysis tools — or linters — report errors that infringe on some rules. For most of these, the user has to fix the problem manually, but some linters and provided rules can fix the issue automatically, which is a huge boon for the user's experience as well as a large time saver.

`elm-review` has supported automatic fixes since the start, improving on it release by release. With today's release, rules gains the ability to provide a fix that spans multiple files!

I'll explain through an example. The [`NoUnused.CustomTypeConstructors`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-CustomTypeConstructors) rule reports custom type constructors that are never used.

```elm
type MyType
    = Used
    | Unused
   -- ^^^^^^ This type constructor is never used

someValue =
    someFunction Used

someOtherFunction value =
  case value of
    Used -> 1
    Unused -> 2
```

This rule already provides an automatic fix which removes the unused variant:

```diff
 -- ELM-REVIEW ERROR ----------------------------------------- src/MyType.elm:6:7

NoUnused.CustomTypeConstructors: Type constructor `Unused` is not used.

5|     = Used
6|     | Unused
         ^^^^^^

This type constructor is never used. It might be handled everywhere it appears,
but there is no location where this value actually gets created.

I think I can fix this. Here is my proposal:

  5|     = Used
-  6|     | Unused
  7|
 ···
 17|
- 18|        Unused ->
- 19|            2
 20|

? Do you wish to apply this fix? › (Y/n)
```

Unfortunately, this has a limitation: if the type is exposed to other modules and referenced elsewhere — even if it's still reported as unused — then no fix is provided, because fixing part of the issue and leaving the user with a compiler error is way worse than not providing a fix.

Here's the same example but the type declaration is in one module and the references are in another.

```elm
module MyModule exposing (MyType(..))

type MyType
    = Used
    | Unused
   -- ^^^^^^ This type constructor is never used
```

```elm
module OtherModule exposing (someValue)

import MyModule

someValue =
    MyModule.Used

someOtherFunction value =
  case value of
    MyModule.Used -> 1
    MyModule.Unused -> 2
```

`elm-review` is able to analyze this just fine because it supports multi-file analysis, but it couldn't provide a fix that removed both the definition and the references. Therefore, even if the rule marks something as unused, no fix is provided because fixing part of the issue and leaving the user with a compiler error is way worse than not providing a fix, as is explained in the [guidelines](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Fix#guidelines).

This limitation is however now a thing of the past: the rule is henceforth able to provide a fix that removes the variant in the entire codebase at once!

```elm,diff
module MyModule exposing (MyType(..))

type MyType
    = Used
-    | Unused
```

```elm,diff
module OtherModule exposing (someValue)

import MyModule

someValue =
    MyModule.Used

someOtherFunction value =
  case value of
    MyModule.Used -> 1
-    MyModule.Unused -> 2
```

This should make the task of removing unused code much faster.

I am working on several other rules that can benefit from this too, such as [`NoUnused.Parameters`](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Parameters) which doesn't provide fixes at all at the moment.

To use this in your rule, check out the documentation for the [new provided functions](https://package.elm-lang.org/packages/jfmengels/elm-review/2.15.0/Review-Rule#multi-file-automatic-fixes).

## Deleting files

As part of the multi-file fix focus, another feature made it in the fix mix: Deleting files.

If you've used `elm-review` for a while, I'm sure you've seen the `NoUnused.Exports` rule (or formerly the `NoUnused.Modules` rule) report that a file was entirely unused, and should be removed. Well, that can now be automated!

```
-- ELM-REVIEW ERROR ----------------------------------------- src/MyType.elm:1:8

NoUnused.Exports: Module `MyType` is never used.

1| module MyType exposing (..)
          ^^^^^^

This module is never used. You may want to remove it to keep your project clean,
and maybe detect some unused code in your project.

I think I can fix this. Here is my proposal:

    REMOVE FILE src/MyType.elm

? Do you wish to apply this fix? › (Y/n)
```

The fix is only applied if you run the CLI with `--allow-remove-files`. The main reason is to protect people from losing irrecoverable data by deleting a file with uncommitted changes or an entirely untracked file. In the future, I hope to find ways when such a change is reasonably safe to apply.

In the future, there is the possibility of having fixes **create files**, which I've tried to keep possible without a breaking change, but I've left it off for now as it has more complications to handle (file permissions and owner, figuring out what to do when file already exists, ...), while not that many use-cases have been proposed in practice, making it hard to figure out the best design for it. Please open an issue if you think this could be useful to you.

Check out the documentation for [`Review.Rule.removeModule`](https://package.elm-lang.org/packages/jfmengels/elm-review/2.15.0/Review-Rule#removeModule) and [`Review.Rule.removeExtraFile`](https://package.elm-lang.org/packages/jfmengels/elm-review/2.15.0/Review-Rule#removeExtraFile) to learn more.

## New test expectation functions

I find it important that tests for rules do thorough checks to help verify that things are as expected, including fixes. Because there is a lot more capabilities this time, a lot of work had to be put in the rule tester as well under the hood.

On the public side of things, a number of functions to indicate what is expected have been added, the main one being [`Review.Test.shouldFixFiles`](https://package.elm-lang.org/packages/jfmengels/elm-review/2.15.0/Review-Test#shouldFixFiles) , which you should use over [`Review.Test.whenFixed`](https://package.elm-lang.org/packages/jfmengels/elm-review/2.15.0/Review-Test#whenFixed) when a fix affects other files than the reported file.

You can now also provide fixes with global errors, which is why there are now functions like [`Review.Test.expectGlobalErrorsWithFixes`](https://package.elm-lang.org/packages/jfmengels/elm-review/2.15.0/Review-Test#expectGlobalErrorsWithFixes).

## Failure message output

When a rule test fails, I find it important that enough information is provided for the rule author in a clear manner so that they can solve the issue.

I have in this version improved some of the test failure message, with a lot of focus on the ones for failing fixes which didn't provide as much information as would have been ideal.

Here is the kind of output you can now expect:

```
INVALID SOURCE AFTER FIX

I got something unexpected when applying the fixes provided by the error for module `A` with the following message:

  `Let value was declared prematurely`

I was unable to parse the source code for src/A.elm after applying the fixes:

Unexpected char at row 3, column 3
Unexpected char at row 3, column 3
Expecting number at row 3, column 3

Here is the result of the automatic fixing:

  `` `
	module A exposing (..)
	a =
	  #Maybe.map
		  (\b ->
			  let
				  z = 1
			  in
			  z
		  ) <| x
  `` `

Here are the individual edits for the file:

  [ Review.Fix.insertAt
	  { row = 8, column = 11 }
	  """let
			  z = 1
		  in
		  """
  , Review.Fix.removeRange
	  { start = { row = 3, column = 3 }, end = { row = 6, column = 3 } }
  , Review.Fix.insertAt
	  { row = 3, column = 3 }
	  "#"
  ]

This is problematic because fixes are meant to help the user, and applying
this fix will give them more work to do. After the fix has been applied,
the problem should be solved and the user should not have to think about it
anymore. If a fix can not be applied fully, it should not be applied at
all.
```

I hope these are helpful. Please reach out or open an issue if you think they can be improved even more.

## Additional notes on package changes

The `Fix` type is now inaptly named, as it only deals with individual file edits. I have therefore introduced a new `Edit` type which aliases to `Fix`, and used the term "edit" where appropriate in the new function names and documentation. I will remove the `Fix` completely in a future major version (or rather rename the new `FixV2` to `Fix`) to avoid a major version bump right now. Sorry about the confusion in the meantime!

Multi-file fixes and file removals are only supported if you upgrade to the latest versions of the Elm package of the `npm` CLI. Multi-file fixes will be ignored by older versions of the CLI, so you should not end up with broken fixes if you only upgraded the Elm package. The CLI will now however require using `2.15.0` of the Elm package.

This package version also adds a new convenience function for project rules [`Review.Rule.withModuleContextWithErrors`](https://package.elm-lang.org/packages/jfmengels/elm-review/2.15.0/Review-Rule#withModuleContextWithErrors)  
to report errors while in the `fromModuleToProject` function. This can help avoid duplicate work that would otherwise be done in both the final module evaluation and in `fromModuleToProject`.

A few functions have now also been deprecated. You can read the full changes on the package's [CHANGELOG](https://github.com/jfmengels/elm-review/blob/main/CHANGELOG.md#2150---2025-02-11).

## CLI changes

The CLI has a few new flags. The first one is `--allow-remove-files`, which I have mentioned before.

The second one is `--fix-all-without-prompt`, which allows you to run `elm-review` and apply fixes just like with `--fix-all` but without being prompted to confirm applying the changes. This can be quite useful if you need to apply fixes as part of an automated script for instance.

To be transparent, this flag has been there for years but remained undocumented, as I'm worried about users abusing it in a way that would hurt them, for instance by applying all fixes and not reviewing the changes. I still think it's possible people will shoot themselves in the foot with it, but it is also a reasonable tool for some applications, so here it is.

### Explaining fix failures in the CLI

The last new flag is for rule authors. Similar to the improvements for test failure messages, the `--explain-fix-failure` will make it so that the CLI prints out much more information about why an automatic fix failed, making it much easier to fix the issue. This was often a pain point for them as figuring out the issue required them to create a unit test, which could sometimes be difficult.

Without the flag, you'll get to see this message:

![](/images/multi-file-fixes/failure-succinct.png)


With the flag, you'll get to see this message:

![](/images/multi-file-fixes/failure-detailed.png)

Again, please reach out or open an issue if you think the output can be improved.

### Project maintenance

[lishaduck](https://github.com/lishaduck/) has helped tremendously with the maintenance of the CLI project. A major part of that includes finalizing the adoption of TypeScript ([using JSDoc](https://www.typescriptlang.org/docs/handbook/jsdoc-supported-types.html)) that I started a long time ago. I wish to thank them as well as [marc136](https://github.com/marc136) and [henriquecbuss](https://github.com/henriquecbuss) for helping out.

Surprisingly, the addition of TypeScript did not lead us to discover any bugs, which is a bit disappointing considering how much effort was put in. Hopefully it will at least make it easier to maintain the code in the future.

lishaduck also removed a few `npm` dependencies of the CLI. Then they also helped out with improving the test suite, and a bunch of other maintaining tasks.

## Node.js support

When v2.0.0 released in 2020, we supported Node.js v10 and newer. At some point, I introduced worker threads that required Node.js v12, but still I made it work for v10 in a slightly degraded but unnoticeable manner (only performance was affected). I had set the `engines` field of the `package.json` in a way that would indicate the versions I wanted to support, because I really wanted.

Unfortunately, some years later, through dependencies slipping through under the project's feet, some *indirect* dependencies made it in that required later versions of Node.js, notably v14 or higher. At some point, the CLI stopped working for v10 and v12 without me noticing.

I am still unsure whether it's something I can do much against, as I can only control direct dependencies and their ranges, but because some underlying indirect dependencies stop supporting older versions of Node.js in minor/patch changes, it feels out of my control.

With this version, I'm officially dropping support for v10 and v12, in favor of only 14 and up (specifically `14 >=14.21 || 16 >=16.20 || 18 || 20 || >=22`). I really dislike doing this outside of a major version, but considering it hasn't caused issues for users in practice (that I've heard) and that a major version would be more painful and confusing for existing users, that's the way we'll go this time.

We now have tools to help identify when we stop supporting the Node.js versions we wish to support, which I *hope* will be enough.

## More changes for the CLI

Since I looked at the reporting of errors, I've also slightly improved the formatting. Diffs will show up nicer, and the number of global errors is now reported separately from the number of file errors.

The `--compiler` flag now additionally resolves the compiler path using the `PATH` environment variable (more easily enabling `elm-review --compiler lamdera` for instance).

Similarly, the `--elm-format-path` flag now additionally resolves the path to `elm-format` using the `PATH` environment variable.

`elm-review new-package` had a bug which created an initial rule of the incorrect type, which has now been fixed (thanks [@mateusfpleite](https://github.com/mateusfpleite)!).

For tooling authors that aim to use `elm-review` (editors, etc.), a new `"fixV2"` field has been added to the JSON output as a replacement for the henceforth deprecated `"fix"` field.
I have also added a `"version"` field to help detect breaking changes in the JSON output in the future, as well as a `"cliVersion"` field in order not to have to run `elm-review --version` for whatever use-case that might serve.

The JSON output changes are detailed in the [tooling integration](https://github.com/jfmengels/node-elm-review/blob/main/documentation/tooling-integration.md) document.

You can read the full changes on the CLI's [CHANGELOG](https://github.com/jfmengels/node-elm-review/blob/main/CHANGELOG.md#2130---2025-02-11).

## Afterword

I'm personally very much looking forward to using the rules with multi-file fixes, I think they will feel very good. I hope you will enjoy these changes as well!