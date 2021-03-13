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

This time, I set off to work on a small feature, instead of bigger tasks that I had been working on, to get more immediate gratification from my work and get a feel-good boost. In this case,

There is just one problem with that: There are no more small features.

TODO

- node-elm-review report of global errors
- Add functions enabling this
- testing global errors
- TODO Mention global errors and configuration errors in the tooling-integration document
- Documentation
- Writing tests
- Writing/adapting rules using global errors
- Writing an announcement like this one

TODO Talk about creating a wholesome experience.

All of these tasks also seem straightforward after the fact, but an announcement like this skips over the several attempted designs or implementations that have an impact on the other tasks. For instance, in this case, I had started with a very different API for testing. Once I was done, I noticed it was wonky and completely changed it, which required big changes in the core implementation too.

Part of the smaller tasks that remain are fixing bugs, because they are indeed pretty fast to fix. Because I put a lot of work into making the experience great, I kind of see my project as a nice spherical balloon. If there is a bug or a part of the experience that is sub-par, then it's like if there is a whole in the balloon. Fixing a bug often takes relatively little time, so every time I do that, the sphere becomes "whole" again, which makes me feel good.

If you are working on a project where the experience is not great, then it's like a random shape with a lot of holes. Fixing a bug or improving the experience in one part doesn't bring a lot of joy, because it doesn't feel like the overall shape has changed: it's still a random shape with a lot of holes.

I recommend trying to get a project as soon as possible to that nice spherical shape before making it expand further. The users will like it more, and you will feel better maintaining it.
