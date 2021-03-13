---
title: Global and configuration errors
date: '2021-03-13T14:00:00.000Z'
---

TODO Table of contents

- Global errors
- Configuration errors
- Test dependencies

# A quest for holism

> Incorporating the concept of holism, or the idea that the whole is more than merely the sum of its parts, in theory or practice:
>
> -- Definition of the word **holistic**

I took a week off from work recently to relax and do fun stuff. One of the things I like doing and did during that week was to work on `elm-review`.

This time, I set off to work on a small feature, instead of bigger tasks that I had been working on, to get more immediate gratification from my work and get a feel-good boost.

There is just one problem with that: small features are rare, and as a project grows, increasingly so.

When I intended to add global errors, which is a pain point I felt (rarely, but surely), I figured the task would be relatively easy and fast.

TODO

- node-elm-review report of global errors
- Add functions enabling this
- Allowing users to test global errors
- Fail tests where unexpected global errors are reported, with [compiler-like failure messages](/great-failure-messages)
- TODO Mention global errors and configuration errors in the tooling-integration document
- Documentation
- Writing tests
- Writing/adapting rules using global errors
- Writing an announcement like this one

TODO Talk about creating a wholesome experience.

All of these tasks also seem straightforward after the fact, but an announcement like this skips over the several attempted designs or implementations that have an impact on the other tasks. For instance, in this case, I had started with a very different API for testing. Once I was done, I noticed it was wonky and completely changed it, which required big changes in the core implementation too.

I had a very similar experience with the work on introducing the `--template` flag which allows users to run `elm-review` with a configuration they found on GitHub, as I explain in the [announcement post](/2.3.0-just-try-it-out/).

How complex can it be to use a remote configuration? Instead of taking the

TODO template feature

- TODO new-package, system of `preview/` and `example/`
- Allowing --template in `elm-review init --template` (as detailed in [the announcement](/2.3.0-just-try-it-out#new-package) and the [maintenance document](https://github.com/jfmengels/elm-review-unused/blob/master/maintenance/MAINTENANCE.md))
- Nice error messages for anything that may go wrong
- Bypassing GitHub API rate limits through a flag.
- Re-using the feature to download the default configuration for getting an up-to-date review configuration.
- TODO

Part of the smaller tasks that remain are fixing bugs, because they are indeed pretty fast to fix. Because I put a lot of work into making the experience great, I kind of see my project as a nice spherical balloon. If there is a bug or a part of the experience that is sub-par, then it's like if there is a whole in the balloon. Fixing a bug often takes relatively little time, so every time I do that, the sphere becomes "whole" again, which makes me feel good.

If you are working on a project where the experience is not great, then it's like a random shape with a lot of holes. Fixing a bug or improving the experience in one part doesn't bring a lot of joy, because it doesn't feel like the overall shape has changed: it's still a random shape with a lot of holes.

I recommend trying to get a project as soon as possible to that nice spherical shape before making it expand further. The users will like it more, and you will feel better maintaining it.
