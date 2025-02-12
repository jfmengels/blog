---
title: Hacktoberfest 2020
published: "2020-09-29"
---

[Hacktoberfest](https://hacktoberfest.digitalocean.com/) will be starting in two days, and it's a good opportunity to get started in open-source and help out the projects you like or depend on. It's a good opportunity because the maintainers will create a lot of issues labeled with `hacktoberfest`. These are usually approachable but they all try to bring value to the project, no "please fix that typo over there".

If you have read the [1-year anniversary](/1-year-anniversary) blog post that I'm releasing at the same time as this post, I hope it got you excited in participating in the tool's journey.

I have prepared a list of tasks that I think will be interesting to solve. I will create more during the course of October, including potential low-hanging ones from the other blog post, but the initial issues revolve around the same thing that got me into the realm of static analysis: writing rules.

I will be celebrating every pull request with a gif of Leonardo (or whoever you specify when making the pull request), like my pull request was [when I started](https://github.com/avajs/eslint-plugin-ava/pull/11)!

### elm-review-documentation

Back when I released `elm-review` v2, my goal was to focus on this package right afterwards, whose aim is to make a lot of checks related to a project's documentation and that could provide real maintenance help for package maintainers and application developers. I ended up focusing on other things, so I figured Hacktoberfest would be a good opportunity to get this project moving again.

This is the [list of rules](https://github.com/jfmengels/elm-review-documentation/issues) that I am proposing for Hacktoberfest (note that I won't mention the bugs, though I would really appreciate if those were tackled too!):

- [Make the test script run on Windows](https://github.com/jfmengels/elm-review-documentation/issues/8) - This is so that people on all operating systems can contribute. This one got some help early, so it's already not for grabs anymore 😄
- [Detect links to non-existing sections](https://github.com/jfmengels/elm-review-documentation/issues/3) - Helps detect problems when linking to a section (exposed functions and types each have a section), and helping discover out of date documentation.
- [Detect duplicate sections](https://github.com/jfmengels/elm-review-documentation/issues/4) - Helps prevent links to a section not ending up where you expect.
- [Make sure that all the exposed things in the module have a corresponding @docs and vice-versa](https://github.com/jfmengels/elm-review-documentation/issues/5) - Helps keeping the docs up-to-date.
- [Detect syntax errors in code examples](https://github.com/jfmengels/elm-review-documentation/issues/6) - Helps detect invalid and therefore unhelpful examples
- [No pointing to resources on master](https://github.com/jfmengels/elm-review-documentation/issues/7) - Helps resources (like images) never break because the resource was hosted on `master` and got removed

### elm-review-unused

[`elm-review-unused`](https://github.com/jfmengels/elm-review-unused) has some issues and all of them could use some help.
There are some bugs, as well as improvements to existing rules that could report more unused code, as well as new rule ideas to also detect new code.

- [Report unused imports using `exposing (A(..))`](https://github.com/jfmengels/elm-review-unused/issues/3)
- [Report unused custom type constructors in more cases](https://github.com/jfmengels/elm-review-unused/issues/2)
- [Report unreachable code](https://github.com/jfmengels/elm-review-unused/issues/10)
- [Report unused record fields](https://github.com/jfmengels/elm-review-unused/issues/15)
- [Report unused tuple values](https://github.com/jfmengels/elm-review-unused/issues/16)
- [Make NoUnused.CustomTypeConstructors smarter around phantom types](https://github.com/jfmengels/elm-review-unused/issues/4)

### elm-review-the-elm-architecture

This [package](https://github.com/jfmengels/elm-review-the-elm-architecture) to report bad patterns around The Elm Architecture has one rule up for taking and discussing:

- [report when code looks to be split in Model/View/Update/... modules](https://github.com/jfmengels/elm-review-the-elm-architecture/issues/1)

### elm-review-common

For [`elm-review-common`](https://github.com/jfmengels/elm-review-common), no new rules, but it would be great if these two rules could offer an automatic fix:

- [`NoExposingEverything`](https://github.com/jfmengels/elm-review-common/issues/2)
- [`NoImportingEverything`](https://github.com/jfmengels/elm-review-common/issues/3)

### Others

These are all the issues I have been able to come up and formalize at this point. As said before, I'll try to create more during the month. I hope you'll find some to be interesting.

If not, you may find interesting rules in [`elm-review-rule-ideas`](https://github.com/jfmengels/elm-review-rule-ideas). Mention in an issue that you'd like to work on it and I'll try to see if I can get it counted as a Hacktoberfest issue (no promises though).

There will also be a [kick off event](https://incrementalelm.com/hacktoberfest2020/) for the Elm Hacktoberfest, where you can learn more about Elm and open source, and there will be a Q & A session with Dillon Kearns (`elm-markdown`), Keith Lazuka (`intellij-elm`) and me.
Feel free to join the #elm-review and hacktoberfest related channels on the [Incremental Elm Community Discord](https://incrementalelm.com/chat) to ask for help!

Other ways you can help out but that won't count for Hacktoberfest:

- Report bugs or give feedback in the #elm-review Slack channel
- Talk to others about the tool, write blog posts about it
- Pitch in in [design discussions](https://github.com/jfmengels/elm-review-design-discussions)
- [Propose rule ideas](https://github.com/jfmengels/elm-review-rule-ideas)
- [Sponsor my work financially](https://github.com/sponsors/jfmengels)

Thanks for reading until now, and happy Hacktoberfest!
