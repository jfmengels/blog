---
title: Analyzing extra files in elm-review
date: '2024-06-14T12:00:00.000Z'
---

I have written quite a few times, including in my article [The omniscient linter](/the-omniscient-linter), that the more data that an analysis tool can have access to, the better it can do its job and the more things it is able to do.

`elm-review` has access to quite a lot of data already. You could have a rule reporting an error after having visited all of the project's Elm source and test files, `elm.json`, README, and even the dependencies. This is a lot more than what you can usually analyze in other linters (at least without using unexpected escape hatches), where the available data is just the file's contents.

But that is not always enough. Because even though we love Elm and we want to write most of our code in it, a project is usually made out of other files: CSS files (Elm targets browser code after all), JSON files, project maintenance files like `CHANGELOG.md`, JavaScript files, etc.

And those are not available for analysis, even though there's plenty of useful information in there. Until today, that is.

## Requesting access to extra files

With the v2.14.0 release of the `jfmengels/elm-review` Elm package and the v2.12.0 of the `elm-review` CLI, you can now have "extra files" visitors. These are [`Review.Rule.withExtraFilesModuleVisitor`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withExtraFilesModuleVisitor) and [`Review.Rule.withExtraFilesProjectVisitor`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#withExtraFilesProjectVisitor), depending on the scope of the rule, that you can add to your rule while specifying which files you'd like to have access to — using Glob patterns — and a function to visit them.

```elm
import Review.FilePattern as FilePattern
import Review.Rule as Rule exposing (Rule)

rule : Rule
rule =
    Rule.newModuleRuleSchema "SomeRuleName" initialContext
        |> Rule.withExtraFilesModuleVisitor cssFilesVisitor
            [ FilePattern.include "**/*.ext" ]
        |> Rule.withExpressionEnterVisitor expressionVisitor
        |> Rule.fromModuleRuleSchema


cssFilesVisitor : Dict String String -> Context -> Context
cssFilesVisitor files context =
    { knownCssClasses =
        files
            |> Dict.values
            |> List.map parseCssAndExtractClasses
    }
```


For project rules, you will have the possibility to report errors in the extra files, and even to autofix them!

---

To request which files you'd like, I find that a Glob-like pattern is a good trade-off between readability and expressiveness, while also being quite familiar to a lot of people, as its extremely common to use in a command-line environment, as well as quite common in tooling.

I don't think a Glob pattern is enough though, at is it very easy to include files, but exceptions to those patterns are hard to specify. For instance, if you want to have all the `*.ext` files in a project, except the one named `exception.ext`, how would you write your Glob pattern?

To solve this, I looked at the popular [`.gitignore`](https://git-scm.com/docs/gitignore#_pattern_format) files a lot of us are quite accustomed to.

```elm
someRuleDetails
	|> Rule.withExtraFilesModuleVisitor cssFilesVisitor
		[ FilePattern.include "**/*.ext"
		-- Equivalent to !exception.ext in .gitignore files
		, FilePattern.exclude "exception.ext"
		]
```

The [documentation](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-FilePattern) describes in further detail how things work, but basically you have include patterns (regular Glob patterns), exclude patterns (`!file/path.ext`) which are reversible with another include pattern, and exclude directory patterns (`!folder/`) which are irreversible.

Huge thanks to [@miniBill](https://github.com/miniBill) for his work on the Glob matcher, which was a huge unblocker for me.

I will look into potentially using the `FilePattern` API to replace the [`Rule.ignoreErrorsForFiles`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#ignoreErrorsForFiles) function and its friends at some point, as I think that could make quite a bit of sense.

## New rules

I have several rules I have in the works, for which I may or may not do separate announcements but that I will release a bit later.

## Checking and updating the CHANGELOG

One of them is a rule that probably triggered the need to work on this: `Docs.NoMissingChangelogEntry` (see [source code](https://github.com/jfmengels/elm-review/blob/2.14.0/tests/Docs/NoMissingChangelogEntry.elm) and [tests](https://github.com/jfmengels/elm-review/blob/2.14.0/tests/Docs/NoMissingChangelogEntryTest.elm)) which will be released in `jfmengels/elm-review-documentation`. It will check that your `CHANGELOG.md` file has an entry for the current version and autofix that as much as possible. This will be very useful to keep your changelog up to date and automate releases.

For instance, after you've done `elm bump`, running `elm-review --fix` could automatically change your `CHANGELOG.md` file from

```md
# Changelog

## [Unreleased]

Stuff happened

## 1.2.0

More stuff happened

## 1.1.0

Stuff happened

[Unreleased]: https://github.com/author/package-name/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/author/package-name/releases/tag/1.2.0
[1.1.0]: https://github.com/author/package-name/releases/tag/1.1.0
```

to

```md
# Changelog

## [Unreleased]

## [1.2.1]

Stuff happened

## 1.2.0

More stuff happened

## 1.1.0

Stuff happened

[Unreleased]: https://github.com/author/package-name/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/author/package-name/releases/tag/1.2.1
[1.2.0]: https://github.com/author/package-name/releases/tag/1.2.0
[1.1.0]: https://github.com/author/package-name/releases/tag/1.1.0
```

This was previously not possible because `elm-review` did not have access to the file at all.

I already know that after this gets released, I won't ever think about updating the file manually when cutting a new release, and I'll make this the default for all new `elm-review` packages and Elm package templates.


## CSS classes

I also have 2 rules related to CSS that look at `.css` files, that will make it into a new `jfmengels/elm-review-css` package.

`Css.NoUnknownClasses` will detect when in Elm `view` code you reference a CSS class that has not been declared in any `.css` file.

```elm
view model =
	Html.span
		[ Html.Attributes.class "unknown-class" ]
		--                       ^^^^^^^^^^^^^
		[ Html.text model.text ]
```


To complete it, there will be `Css.NoUnusedClasses` that reports classes defined in `.css` files that are never referenced in Elm code, and it could even automatically remove them.

My current CSS file parser is very naive meaning there are still some false positives, and there is quite some considerations mainly around exceptions that deserve putting some thought into the API.

In practice, this is a rule I initially wrote at work a few years ago, but it relied on a code generation step where a script would load all the CSS files, parse them and generate an Elm file like below, which the rules would then use. While it works, relying on a code generation step can be a bit painful such as with out-of-sync reports when forgetting to run the generation.

```elm
module CssClasses exposing (all)

all : List String
all =
  [ "red-rose"
  , "blue-violet"
  , "sweet-sugar"
  , "insert-funny-twist"
  -- ... 
  ]
```

## Future enhancements

On top of asking for the contents of additional files, I also wanted to be able to know the existing of a list of files. For instance, if an Elm file references an image file in `view` code, then it could be valuable to know whether this file exists or not, for instance so that you can report when you made a typo in the name of a file.

Unfortunately, that is not yet present in this version, but I hope to have that available later, re-using some of the same mechanisms needed for the feature presented here. Well, we can already do it, but we would be loading image file contents unnecessarily, which would be unnecessarily slow.

## Afterword

I hope this release will be interesting to you. I believe it will particularly be useful for projects with specific needs and desires to have more safety around the use of some resources. It's more like that this will be used in private application projects, rather than in public package projects such as `jfmengels/elm-review-css`, but I'd love to get surprised!

Please let me know if you like it, what you use it for, and create issues on GitHub if you encounter bugs!

As you may have noticed, it's been a while since I have made a release for `elm-review`, at least one that was worth writing a blog post about it. Actually, there has been v2.11.0 of the CLI which introduced a running offline support while fixing recurrent stability issues, but I have not been able to find the motivation to write about it (yet).

Anyway, my drive to work on OSS has been low for a while, partially because my mental state has been pretty bad and I've had a few too many false hopes about how to do OSS full-time which has been a bit crushing. Also, I bought a house, so not everything is negative, but that was more time-consuming than I expected to. Also, genuinely, please save me from watching YouTube, YouTube shorts is the worst thing that has happened to me in recent times but it's so hard to get away from.

I often end up ending my blog posts by asking to sponsor me. I'm not sure I will today ([although...](https://github.com/sponsors/jfmengels)) as — even though I really appreciate if you do, and all those that have sponsored me so far 🙏 — as I believe that unless companies do it with large donations, it's not going to help me towards my goal of doing OSS full-time, and so far no company doing Elm has offered to. So the plan right now is to quietly stick to my day job and do OSS in my spare-time. We'll see how or if this evolves.

So instead of asking for sponsorship, let me ask you something else, which I have always wanted and requested but probably not explicitly enough: I'd love your help maintaining `elm-review`.

`elm-review` is the thing that I'm most proud of in my entire programming career, and is one of the core tools that makes Elm a joy to work with. It is one of the most reliable static analysis tools out there all languages included, including those built by companies with entire teams working on it. 90% of the credit goes to the fact that it's analyzing the Elm language, but still!

I don't know how my mental health will evolve, or if my spare time will be spent on other things in the future, but I really want to keep this project alive because it's so good and so useful. So if you want to help out, there's plenty of things to do: write new rules and improve existing ones, add new features to the package or the CLI, help with getting `elm-syntax` to its `v8`, improving the CSS parser, etc. Look at existing issues on the different repositories or join the #elm-review channel on Slack, those are likely good places to start, even just chatting can be helpful.

I'm not great at coordinating OSS projects because `elm-review` has mostly been just me, but I'd love to get help, even if it's just on one package (just like I got awesome help on `elm-review-simplify`, a great project with lots of things to do still). I only hope that I will have the mental fortitude and time to get to your issues and PRs and not to waste your time.

Thank you for reading up until here, sorry for the bad vibes, enjoy the new release, I'm heading to Elm Camp to get inspired by awesome people!