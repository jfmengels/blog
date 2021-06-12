---
title: Disable comments in static analysis tools
date: '2021-06-15T12:00:00.000Z'
---

As the author of [a static analysis tool for Elm](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/),
I like to read the documentation of similar tools that I come across, to see if they have any cool ideas that I can and
should implement in my own.

There is one feature that I have trouble **not** seeing in static analysis tools/linters, and that is
**allowing disabling reports through special comments**, and I consider it a mistake that gets copied
over and over.

I'll go over what these are, the problems these entail, why people use these, and what better alternatives are available. 


## The concept

"Disable comments" are comments that you can find in the source code that disable the reports of a static analysis tool
for some section of the code. Some tools call it disabling the rule (themselves sometimes named "checks"),
some call it suppressing errors, but they're the same thing.

They are usually available in multiple flavors (examples are from a different language/tool every time).

- Disable for entire files (`deno_lint` for Deno)

```js
// deno-lint-ignore-file
function foo(): any {
  // ...
}
```

- Disable rules from an opening line until an optional re-enable comment (`SwiftLint` for Swift)

```swift
// swiftlint:disable colon
let noWarning :String = ""
// swiftlint:enable colon
```

- Disable for a single line (`ESLint` for JavaScript)

```js
// eslint-disable-next-line no-alert
alert('foo');
```

```python
a, b = ... # pylint: disable=unbalanced-tuple-unpacking
```

- Disable for a whole construct (function, class, ...) (`Scalafix` for Scala)

```scala
@SuppressWarnings(Array("scalafix:DisableSyntax.null"))
def getUser(name: String): User = {
  if (name != null) database.getUser(name)
  else defaultPerson
}
```

- (less common) Disable with a reason (`Staticcheck` for Go)

```go
func TestNewEqual(t *testing.T) {
  //lint:ignore SA4000 we want to make sure that no two results of errors.New are ever the same
  if errors.New("abc") == errors.New("abc") {
    t.Errorf(`New("abc") == New("abc")`)
  }
}
```

## Issues with disable comments

There are several problems with the usage and enablement of disable comments.

### Unwarranted use

The most important one for me is that it allows people to get around rules that are supposed to prevent important bugs,
help them and align what they write with the choices their team made.

From experience, I find that people reach out for disable comments *way* quicker than they should, and often not for good
reasons. We'll go through why people use disable comments in a later section (TODO link).

### Abusive disable comments

Sometimes these disable comments are used abusively in a way that disable *all* rules instead of just the few
that reported problems. There are some instances where that is probably appropriate (vendored code, generated code, ...)
but this would be a suboptimal solution.

Disable all comments are sometimes used mistakenly, or in places where a few rules that are "okay to ignore" are
reporting issues. The problem is the code covered by the comment can later change and contain important problems that
will not be reported. To avoid any bad surprises, it is much better to list the rules to disable than to disable all.

I wrote a rule to [forbid disable all comments](https://github.com/sindresorhus/eslint-plugin-unicorn/blob/main/docs/rules/no-abusive-eslint-disable.md)
back [in my `ESLint` days](https://github.com/sindresorhus/eslint-plugin-unicorn/pull/33). In `ESLint`'s case, not saying
which rule to disable meant disabling all the rules, which is I think a bad default behaviour to have. Make the nice
things easy and the bad things harder, not the opposite. I found many places where this kind of disable comment was used,
and never justifiably so.

This issue would be caught by the rule I wrote, but I don't expect this rule to be enabled in most people who use `ESLint`
since it's not part of the core rules or tool, and therefore not enabled by default. This pushes additional work to the
user.

### Unnecessary disable comments

In some tools, the tool will report when disable comments are used but doesn't suppress anything anymore, usually because the code
it covers has since changed. I don't see it present in all the tools, nor not always enabled by default. If you are using a tool with
disable comments, check whether it offers this feature and whether you have enabled it, as that could clean your codebase somewhat.

## Why do people use disable comments in the first place?

I find that disable comments have a surprisingly prevalent place in some tools' documentation.
[`deno_lint`](https://lint.deno.land/)'s website goes as far as to only have 2 pages: the list of rules, and how to ignore them.

Most of the guides I see have dedicated pages for this feature, but only explain how to do it, not why you'd want to use it,
when you'd need to use it, and when it would be ok or not ok to use it. **There is a lack of guidelines** for the user,
and I think this has shown in the industry when you look at how people use—and create—these kinds of tools.

It feels to me like this feature gets added to the tool simply because it was in the other static analysis tool that
they know, reinforcing the feeling for the next one that it's an essential feature.

A comment I've received several times with `elm-review` is: "Very cool and useful project. I think it would be a nice
addition if we could ignore errors through comments". Every time I received this comment I asked why they think it would be useful,
and I never got a good answer. Usually it's something like *"well... similar tools have it?"*.

### Why do users want disable comments

I see multiple reasons why people would like to disable rules.

#### Prioritization

The first one is prioritization, when you acknowledge the reported issue but deem it too costly to resolve right now
(compared to delaying a bug fix or the release of a feature), pushing the fix for later. I am not the one to decide or
to judge or decide whether this is wrong or right, and I think this is likely necessary to some extent.

#### Not agreeing with the rule

Sometimes an issue is reported to you, and you don't agree with what the rule is trying to forbid or enforce. I find
this to be most common with rules related to code style, which as you probably know can lead to heated debates.

`elm-review` has very few rules related to code style, primarily
because the community has adopted and embraced a [code formatter](https://github.com/avh4/elm-format) early enough in
the development of the language, before people started to have strong opinions. This means that we can ignore most of
these concerns and focus on more impactful rules. I strongly recommend checking out the code formatters for your language,
they can help you and your team out more than you think, and they are simply much better at handling this concern than
a linter.

TODO Disable the rule
TODO Not enable the rule in the first place
TODO CHecklist




As said before, users are often eager to go for disable comments.

So, let's go through why users would want disable comments, why the tool's author want disable comments.

TODO Why disable things? Vendored or generated code, ..., special rules for tests

People don't understand the rule, and/or think it's a false positive.

People often say that when you accept TODO with a linter, code formatter you're happier. Disable comments allow
you to fight back.

THere is a risk of disabling too much, which seems to be an easy default for some linters, and even mandatory for some (TODO check if you can find one)

https://github.com/sindresorhus/eslint-plugin-unicorn/blob/main/docs/rules/no-abusive-eslint-disable.md
https://github.com/sindresorhus/eslint-plugin-unicorn/pull/33

TODO Example of disabling too much


TODO Example of stray and unnecessary disable comments


## Disable through configuration, and better alternatives

Instead, make your rules more configurable, or don't write them at all (sometimes they're simply bad ideas).

Give guidelines as to when it's okay to disable things.

Let each rule decide whether they can be disabled through comments? But don't make it the default. 

Allow rules to report configuration errors when the passed options are unexpected. Don't let the rule run with invalid premises.

Help them fix the issues with automatic fixes so that they can fix the issues quickly.

Solution for vendored/generated code.
Solution for temporary disable.

Kudos to Go vet (https://github.com/golang/go/issues/17058)


TODO No difference between ignored elements temporarily due to a lack of time (remain to be resolved), and the ones that
are false positives (have been investigated). Both fall in the same category and will likely stay as is.

https://stackoverflow.com/questions/2891758/when-to-stop-following-the-advice-of-static-code-analysis