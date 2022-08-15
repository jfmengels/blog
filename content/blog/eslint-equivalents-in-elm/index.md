---
title: ESLint equivalents in Elm
date: '2022-08-16T00:00:00.000Z'
---

In the JavaScript community, [ESLint](https://eslint.org/) is a widely adopted linter for JavaScript that is a huge help in making JS code more maintainable.

In the Elm community, the closest equivalent is [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/), but that one has a lot less rules than ESLint (and not because I'm not writing them). That is somewhat understandable because we already have a compiler checking for some of those issues, and we have `elm-format` to handle styling-related issues.

[Mario Rogic](https://twitter.com/realmario) and I thought it would be really interesting to see how many of the ESLint rules applied in the Elm ecosystem. So I went through every single one of the 263 "core" ESLint rules (not from packages, there are so many that it's not even funny to consider doing) and noted that down.

The results can be found on the [Elmcraft](https://elmcraft.org/compare/javascript/eslint/) website. Note that some of the things are interactive 🙂

It was a bit hard to categorize everything (some things can fit into multiple categories), but I tried my best to be objective.

Huge thanks to Mario for editing the article and talking me into researching this.
