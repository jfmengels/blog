---
title: Problem with concurrent linter fixes
slug: concurrent-linter-fixes
published: "2026-08-26"
---

Today I want to talk about a problem that occurs in linters (ESLint for JavaScript in this article, but it's not the only one) where the linter will fix multiple issues concurrently, and in doing so introduces a problem that would not have been introduced if fixes were only applied after a re-analysis of the code.

## The problem

*(All code can be found in [this repository](https://github.com/jfmengels/eslint-concurrent-fixes-sscce).)*

Let's say we want to analyze this `example.js` file:

```js
let scores = [ 0, 100, 40, 60 ];
let averageScore = sum(scores) / scores.length;
console.log(averageScore);

function average(array) {
  return sum(array) / array.length;
}

function sum(array) {
  let sum_ = 0;
  for (const elem of array) {
    sum_ += elem;
  }
  return sum_;
}
```

We can determine 2 improvements here:
- We define `averageScore` as the average of `scores`, but we are computing the average "manually" when there is a perfectly fine `average` function that we could use instead.
- `average` is currently unused, and could be removed from the source code.

The problem is that while these improvements—using `average` in the definition of `averageScore`, and removing `average`— are fine, applying both changes would yield incorrect code:

```js
let scores = [ 0, 100, 40, 60 ];
let averageScore = average(scores);
//                 ^^^^^^^ Unknown reference

// end of file, or just with the definition of `sum`,
// depending on how far the linter goes with the application of fixes.
```

In the repository I linked above, I demonstrate this problem by creating and enabling 2 linter rules:
- `sscce/useAvailableUtils` which replaces code by utility functions available in the same file
  - (While such a rule rule could be nice to have, this rule is extremely naive and tailor-made for this example)
- `sscce/removeUnusedFunctions` which reports and automatically removes never-referenced functions.

*(These 2 rules are written quite naively, to the point that they're unusable in real projects, but are sufficient for this very simple example that is the target of our analysis.)*

## Walkthrough

With these 2 rules enabled, what ends up happening? The linter (in this case ESLint) runs the analysis for all rules for `example.js`, and determines that there are two available fixes:
- One from `sscce/useAvailableUtils` with an autofix replacing `sum(scores) / scores.length` by `average(array)`
- One from `sscce/removeUnusedFunctions` with an autofix removing the definition of the `average` function

Seeing that there are no conflicts for the two fixes—**solely in terms of editing range**—the linter applies them both at once, then re-runs the analysis to find out that `sum` can now also be removed.

## Possible solution

I asked [Nicholas C. Zakas](https://github.com/nzakas) (the creator of ESLint) once about this, and he told me that while this is indeed possible, it wasn't much of a problem in practice. I would tend to agree since I have not in practice encountered this problem nor heard such complaints. But I do believe that this would be more of a problem if ESLint was more aggressive in removing unused code (for instance, by having [`no-unused-vars`](https://eslint.org/docs/latest/rules/no-unused-vars) have automatic fixes) and adding automatic fixes to other rules.

While I agree this is a rare case, its possibility is one that has always scared me when implementing [`elm-review`](https://elm-review.com), my own linter for the Elm language. I have therefore made a choice there that I believe is more sensible (though slower) : applying only a single fix at a time, then re-analyzing the code.

This is what ESLint does:
1. Analyze the project
2. Batch all applicable fixes from reported errors and apply them
3. Throw away remaining errors and go back to step 1, until there are no more fixable errors

This is what `elm-review` does:
1. Analyze the project
2. Find the first applicable fix from reported errors and apply it
3. Throw away remaining errors and go back to step 1, until there are no more fixable errors

This does mean that the linter is spending more time analyzing the project than potentially necessary, but it does mean that it will always only apply fixes that make sense for the files/project at any given point in time.

In this example, if the first applicable fix (the order can be random) was using `average`, then in the second iteration `average` would be considered referenced and would not be removed. The final result would be:

```js
let scores = [0, 100, 40, 60];
let averageScore = average(scores);
console.log(averageScore);

function average(array) {
  return sum(array) / array.length;
}

function sum(array) {
  let sum_ = 0;
  for (const elem of array) {
    sum_ += elem;
  }
  return sum_;
}
```

On the other hand, if the first applicable fix was removing `average`, then in the second iteration there would be no `average` function to use and `averageScore` would be left untouched:

```elm
let scores = [0, 100, 40, 60];
let averageScore = sum(scores) / scores.length;
console.log(averageScore);

function sum(array) {
  let sum_ = 0;
  for (const elem of array) {
    sum_ += elem;
  }
  return sum_;
}
```

Both versions are fine, and unless the linter gives priority to either fix, both versions are in some way improvements to the original code. What is wrong though, is ending up with broken code by trying to apply both fixes at once.

## Conclusion

This problem can come up with any pairs of rules that apply significant code changes that on their own are 100% correct :
  - code removal
  - renames
  - moving statements or expressions
  - etc.

I would consider this issue a blocker when wanting to augment the linter with bolder automatic fixes (ESLint for instance doesn't remove much code as part of automatic fixes).

The solution I went for—re-analyzing the code between fixes—has a definite performance cost. Unfortunately I have not figured out a better solution when I don't control the rules, as both `elm-review` and ESLint support custom rules that are not known to the tool maintainers. Linters that don't support custom rules (which is a critical missing feature IMO) could probably get by by figuring out the collisions beforehand through prioritization for instance.

I really enjoy not having to worry about this problem at all. I don't have to worry about fixes for my rule potentially conflicting (in the sense described here) with the fixes of another rule in specific situations, and I don't have to spend a lot of time debugging such an issue for users that may have.