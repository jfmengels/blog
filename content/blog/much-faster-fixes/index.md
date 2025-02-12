---
title: Much, much faster fixes
published: "2022-11-08"
---

There are new releases for `jfmengels/elm-review` (v2.10.0) and the `elm-review` CLI (v2.8.0) with a lot of new features
and improvements. It's such a big one that I'm going to split it into 2 parts. This first part will mostly deal with the
large performance improvements. The second part will deal with a new feature that allows extracting information from a
project using `elm-review`.

If you want to make use of these changes, you should update these dependencies:

```bash
npm install elm-review

cd review/
elm-json upgrade
```

If you're running into issues where `jfmengels/elm-review` stays stuck as 2.9.x, then try removing `elm-explorations/test`
first (`elm-json uninstall elm-explorations/test`). A new major version of that last package came out since our last release. `elm-json upgrade --unsafe` also seems to work quite well in practice.

Let's get into the new things!


## Simply faster

Before we talk about the new version, I haven't written about the changes I made around mid-September, where I published new
versions of my `elm-review` Elm packages which (also) focused on performance.

I improved performance by removing a bunch of wasteful (smaller and larger) computations. The performance gains differ
from project to project, but according to the reports the tool ran for 75% to even 40% of the time that it did before. So quite a big improvement!
I haven't checked whether the changes made in this specific release increase that even further, but I have a feeling that they do.

I won't go into the details of these changes, but let me know if you want to know more, and I'll share some of my learnings in a different
blog post. Suffice to say, some rules (especially [`NoUnused.Exports`], [`NoUnused.CustomTypeConstructors`] and
[`NoUnused.CustomTypeConstructorArgs`]) were taking exponentially longer than necessary. On my work project, `NoUnused.Exports` was
running for about 30 seconds, and it's now down to 1 or 2 seconds.

How do I know that? Well I simply ran it with `--benchmark-info`. Oh. Yeah. That's a new thing.

You can now run `elm-review --benchmark-info` which will tell you how long it took to run specific parts of `elm-review`'s process,
including the time taken for each rule. This was very valuable as it helped me figure out where I should or shouldn't
focus.


## Much faster fixes

This is **the main change** for this release (well, one of the 2, the other one deserves its own announcement).
If you've ever used `elm-review --fix-all` on a large project, then chances are that it took long enough for your
attention to wander somewhere else.

Just like the Elm compiler for 0.19, I rewrote large parts of the core logic for `elm-review` to be much faster at
fixing issues.

Let's start with the results. I benchmarked it on 2 projects. The first one is [`rtfeldman/elm-spa-example`](https://github.com/rtfeldman/elm-spa-example), which is an amazing example, but that would use a little tidying 😄.
The second one is the Falcon LogScale codebase (where I work) which has around 300k lines of Elm code, on a specifically dirty branch (we fixed all these issues before merging it, obviously).

Before the changes, `elm-review` fixed 247 issues for `elm-spa-example` (mostly the unused code removal) in 27-28 seconds (all results are taken on my Dell XPS 15).

Now it does the same work in 8.5 seconds, which means it's **three times as fast!**

The results are even more impressive for the Falcon LogScale project, the new version fixed around 260 issues in about 3 minutes.
The old version? 40 minutes! This means a **13x speed increase!**


## Old implementation vs new implementation

I have described how the fix-all implementation worked and how it should work many times on different platforms, because
this problem has frustrated me for a long time. So if you've heard it before, it should be the last time (but with more details than usual).

Previously, `elm-review` ran like this:
1. Analyze the whole project with all the rules
2. Go through the list of errors to find a valid fixable error
3. Apply the fix

then go back to step 1 until there are no more fixable errors.

Step 1 would be faster after the initial run because there would be a lot of in-memory caching, but this very simple
algorithm was very wasteful as it re-ran rules over and over even when it was obvious it wasn't necessary to.

The current approach is still quite similar, with a key difference: `elm-review` will abort early on whenever it finds a
valid fixable error.
This means that for instance, if you're running `elm-review --fix`, it might stop — while running the first rule when it's
halfway through the project — because it found a fixable error, and it will then prompt you to apply or ignore the fix.

In `--fix-all` mode, it's slightly different: it will apply the fix on the project in-memory, then resume the analysis
from the most optimal file.

For instance, if [`NoUnused.Variables`] removed a top-level function because it wasn't used anywhere — which
can only be determined after going through the entire file — it would apply the fix, reparse the file, and then resume
the analysis at the start of this file.

For [`NoUnused.Exports`] — which reports functions exposed from a module that are never used in other modules —
we need to wait until all modules have been reviewed to report errors. At which point we'll fix the issue, and
resume starting from the updated and continue to the other files whose results have potentially been impacted by the fix.

If a rule fixes an issue, it will continue the analysis until it finds no fixable errors for the project. After it's done,
we will re-run all the rules we've previously run, followed by the ones we haven't run yet. If we're running rules
A, B, C, D, E, ..., Z (in this order), and rule C finds an issue, then after C is done running, we will run A, B (again)
followed by D, E, ... Z.

Since rules modify the project, it's entirely possible that C changed the project in such a way that A or B will now
start reporting new errors. In fact, `NoUnused.Variables` and `NoUnused.Exports` very commonly remove code that will cause
the other one to start reporting new issues.

So that's the main change: Applying fixes early and reanalyzing only what is necessary, whereas before we simply ran the rules over and over.
This is why finding and applying fixes on the Falcon LogScale project took about 40 minutes, because we were basically
analyzing the project 260 (+ 1) times, and it is a very large project.  


## No more progress bars

With this amazing change comes a sacrifice, and that is the progress bar. Previously, `elm-review` had one that looked
like this:
```
I'm applying fixes! [▇▇▇▇——————] 78/183
```

Since `elm-review` analyzed the whole project, it could remember that it had already applied 78 fixes and know that it
roughly 105 more to go. That last number would often change as the analysis went on, but it was a useful rough metric
to know whether you had a few seconds or a few minutes left to wait.

Since we now stop at the first error, we have no clue how many fixable errors remain, and all that we know is how many
we have fixed so far. Therefore, the progress will now be communicated like this:
```
Fixed 78 issues so far
```

I'm a bit saddened by this loss, but the performance improvements are definitely worth the trade-off. Hopefully, it will
be so fast that you will not even notice the progress messages anymore. 


## New requirement: differentiate fixable from non-fixable rules

For this new approach to be more efficient, we now run the rules in order: rules that provide fixes first, and rules that
don't provide fixes last. This is so that we don't have to (re-)run rules that will never find fixable errors anyway
until we know we can't find any more fixes.

Unfortunately, whether a rule can provide fixes was not a piece of information `elm-review` had so far. This is why there are
now ways to tell `elm-review` whether a rule can provide fixes or not. There is now [`Rule.providesFixesForModuleRule`]
and [`Rule.providesFixesForProjectRule`], to use if you have a module rule or a project rule respectively.

If you're running a rule that will provide fixes but does not indicate it, everything should still work as expected but
the process will be slower than necessary. This is why I ask every rule author (with custom or published package rules)
to please publish a new version of their package if their rules provide fixes 🙏

There is a mechanism in `elm-review`'s test runner to fail the tests if a rule is found to provide a fix without
indicating that it could do so. So if you update the `jfmengels/elm-review` package in your project, your tests should
tell you all that you need to do.


## New flag: --fix-limit=N

I started working on this by focusing on making `--fix-all` faster. At some point, I realized that `--fix` would use
(almost) the same algorithm but with the caveat that it could abort the review process as soon as it found a single
fixable error.

In the implementation I used, this was very easily generalizable to stop after N fixes, and so we now have a new flag
`--fix-limit=N` which tells `elm-review` to abort and prompt after applying N fixes. You can use this along both `--fix`
or `--fix-all`.

I believe this can be quite useful if you know you're going to have large amounts of fixes, and want to review them in
batches. This can also be useful if the process still takes a long time (which I hope is not the case anymore) and/or
you're pressed for time, in which case you can run `elm-review --fix-all --fix-limit=50` for instance and get some
changes committed without waiting for all of them to be fixed.


## Afterword


This summer I spent a lot of time preparing conference talks about static analysis, and thinking about this craft raised many
interesting ideas, yet with little opportunity to put them into practice. I presented my last talk of the year a month ago,
and have been focusing on this ever since.

Getting this out feels very good, because I have been wanting this for a very long time. I had actually worked on the
same problem maybe 1.5-2 years ago, but the performance came out unchanged. I still have no clue what I did wrong back then. 

I have glossed over the work needed to make this change, but I'd say roughly 50% of the core logic has been rewritten
over many steps. I tried hard to catch all problems, but I wouldn't be surprised if some bugs were introduced in this
release. If you find any, please open issues in the [package](elm-review.com) or the [CLI] (pick the one you think is
most appropriate) and please provide as much information as you can think can be valuable to fix the issue.

If you feel like you or your company benefit from my efforts, please consider [sponsoring me](https://github.com/sponsors/jfmengels/)
and/or talking to your company about sponsoring me, I would really appreciate it.

I really hope that you will find pleasure in running `elm-review` at its current fastest (I have more ideas to try out though!), I know I will!

PS: Oh yeah, be on the lookout for the second part of this release.

[`NoUnused.Exports`]: https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Exports
[`NoUnused.Variables`]: https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-Variables
[`NoUnused.CustomTypeConstructors`]: https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-CustomTypeConstructors
[`NoUnused.CustomTypeConstructorArgs`]: https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-CustomTypeConstructorArgs
[`Rule.providesFixesForModuleRule`]: https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#providesFixesForModuleRule
[`Rule.providesFixesForProjectRule`]: https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#providesFixesForProjectRule
[CLI]: https://github.com/jfmengels/node-elm-review