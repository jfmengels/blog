---
title: Why Don’t Software Developers Use Static Analysis Tools to Find Bugs?
date: '2021-06-15T12:00:00.000Z'
---

I found some new scientific papers on static analysis tools (please send me ones you find interesting!) recently, and I
came across one named ["Why Don’t Software Developers Use Static Analysis Tools to Find Bugs?"](https://people.engr.ncsu.edu/ermurph3/papers/icse13b.pdf)
by Johnson et al.

In this paper from 2013, they conduct individual interviews with about 20 software developers who have had or not had
experience with using static analysis tools (mostly people who did though). The sample size isn't very large, but they
share plenty of interesting things that the interviewees said.

Most of what the authors share from the interviewees and interpolate from it, is about the reasons software developers
would want to use static analysis tools, and what pain points they encounter which can cause them to not adopt or to
abandon such a tool.

What I found very interesting (and pleasing. I won't promise an unbiased article) is that almost all of the remarks
indicate the developers and authors want a tool almost exactly like `elm-review`. So let's go over that.

(I'll reference static analysis tools a lot, so I'll shorten it to SAT or SATs)

---

> Susie is a software developer at a small company. She wants to make sure that she is following the company’s standards while maintaining quality code.
>
> [...] Susie decides that her best bet is to install a static analysis tool. She decides to install FindBugs because she
> likes the quality of the results and the fact that bugs can be found as she types; at first, she is very happy with
> her decision and feels productive when using it.

(Note: the paper talks a lot about tools for the Java and C ecosystems, like `FindBugs`, `Lint` or the `IntelliJ` built-in SAT)

TODO remove?

---

> Static analysis tools use well-defined programming rules to find defects early in the development process, when they are cheap to fix.

Just like refactoring, they also help make the code simpler, which helps highlight or even uncover new issues, that
should then also be easier to be fixed.

In some cases, the fixes come naturally. For instance, if you had a function that a SAT tells you has a major flaw that
will crash the application, such as this one:

```js
function formatName(name) {
  var formatter = null;
  return formatter(name);
} 
```

In the example above, calling `formatName` will cause a crash, because we'd be calling a function whose value is `null`.

It's possible that there would be another error reported by the SAT that says the `formatName` is never used, and that
you might as well remove it. It might even provide an automatic fix for it.

By following that advice, you have made the program simpler and have removed the need to fix the implementation of `formatName`.

I imagine that some people when adopting a SAT would first enable the rules that solve the critical issues. Instead, I
would recommend to first reach for the ones that catch the low-hanging fruit, such as the rules that provide automatic
fixes, and then to enable the more critical issues. You'll have an easier time doing it in this order.

> “If I only had an hour to chop down a tree, I would spend the first 45 minutes sharpening my axe.” – Abraham Lincoln.


---

> After using the tool for a while, dealing with the interface became a burden; finding the warnings was not easy and
> when she did, she had a hard time interpreting the feedback.

TODO?

---

> One of the obvious reasons [to use a SAT] is because too much time and effort is involved in manually searching for bugs.

Yes! SATs can be used to find bugs. In some communities, when people talk about SAT they think about "linters" and only
think about code style enforcements. While that is one application for SATs, I find that it's such a under-usage of the
tool.

SATs are a great tools to find bugs in a codebase. It's also one of the rare tools that can find problems in parts of the
codebase that you never look at or never knew existed. If you were told to fix all the bugs in the project, you'd mostly
look at the files that you know well. If you want to broaden the scope of your research, use SATs.

> Anything that will automate a mundane task is great.

Imagine [removing lots of dead code automatically](https://jfmengels.net/safe-dead-code-removal/).

---------------------------------------

As the author of [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/), a static analysis
tool for Elm, I like to read the documentation of similar tools that I come across to see if they have any cool ideas
that I could implement in my own.

There is one feature that `elm-review` doesn't have, and that I have trouble **not** seeing in other static analysis
tools and linters, and that is **allowing disabling reports through specific comments**. I personally believe that it's
a feature with negative value, that gets copied over from one tool to the other.

I'll go over what these disable comments are, the problems they entail, why people use them, why tools support them,
and what better alternatives we can go for.


## The concept

"Disable comments" are comments that you can find in the source code that disable the reports of a static analysis tool
for some section of the code and for some specific "rules" (sometimes named "checks"). Some tools give it a different name, but I'll go with this naming for the rest of the article.

They are usually available in multiple flavors (each of the following example is from a different tool, each of them
supporting most of the flavors).

- Disable for a single line (`ESLint` for JavaScript, `Pylint` for Python)

```js
// eslint-disable-next-line no-alert
alert('foo');
```

```python
a, b = ... # pylint: disable=unbalanced-tuple-unpacking
```

- Disable rules from an opening line until an optional re-enable comment (`SwiftLint` for Swift)

```swift
// swiftlint:disable colon
let noWarning :String = ""
// swiftlint:enable colon
```

- Disable for a whole construct (function, class, ...) (`Scalafix` for Scala)

```scala
@SuppressWarnings(Array("scalafix:DisableSyntax.null"))
def getUser(name: String): User = {
  if (name != null) database.getUser(name)
  else defaultPerson
}
```

- Disable for entire files (`deno_lint` for Deno)

```js
// deno-lint-ignore-file
function foo(): any {
  // ...
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

## Intrinsic issues with disable comments

There are several problems with the usage and enablement of disable comments.

### Disabling rules that should never be disabled

At one of my previous jobs, we once left a `console.log` in our Node.js backend code in production which sent
sensitive information to our log management system such as secret keys. These then showed up in our logs, and we had to remove them manually
(and I might be misremembering/exaggerating, but I _think_ we had little control over our logs and we could not delete
individual logs, only delete all the logs. So that was a fun day).

In order to not have this happen ever again, we wrote an `ESLint` rule to forbid logging values known to contain
sensitive information. From that point on, it became impossible for that code to go to production. Or was it?

Well, no. It was still possible to write that code along with disable comments ignoring that rule. It thankfully didn't
happen again (while I was there at least), but **why should it even be possible?**

There was no instance where we would ever
want to allow this code, yet there was no way to tell the tool to not allow disabling the rule. As far as I know, there
is no static analysis tool out there that has disable comments and allows making some rules not disableable (please let
me know if you know one!).

### Overly greedy disable comments

Sometimes these disable comments are used in a way that disable *all* rules instead of just the few
that reported problems. There are some instances where you may not want the tool report is probably appropriate (vendored code, generated code, ...)
but this would be a suboptimal solution in my opinion (but more on that later).

Disable all comments are sometimes used in places where there are too many rules that are "okay to ignore"
reporting errors, and listing them all would be annoying.

The problem is the code covered by the comment can later change and contain important problems (from "not okay to ignore rules")
that will then not be reported. To avoid any bad surprises, it is much better to list the rules to disable than to disable all.

I wrote a rule to [forbid disable all comments](https://github.com/sindresorhus/eslint-plugin-unicorn/blob/main/docs/rules/no-abusive-eslint-disable.md)
back [in my `ESLint` days](https://github.com/sindresorhus/eslint-plugin-unicorn/pull/33). In `ESLint`'s case, not saying
which rule to disable meant disabling all the rules, which is I think a bad default behaviour, and a too common mistake
made by developers. Make the nice things easy and the bad things harder, not the opposite.

I found many places where this kind of disable comment was used where listing specific rules would have been better.
They would be caught by the rule I wrote, but I don't expect this rule to be enabled in most people who use `ESLint`
since it's not part of the core rules or tool, and therefore not enabled by default. This pushes additional work to the
user.

I found when writing this article that someone from the `ESLint` core team later created [a separate `ESLint` plugin](https://mysticatea.github.io/eslint-plugin-eslint-comments/rules/no-use.html)
that does the same thing along with 8 more rules around disable comments. 
after I wrote my rule, duplicating the idea of my rule and adding more rules, totalling 9 different rules to make sure
users use this feature well (or not at all).

To me this is a sign that this feature can be misused in plenty of ways that the authors are not comfortable with.

### Unnecessary disable comments

Some tools will report when disable comments are used that don't suppress anything anymore, usually because the code
it covers has since changed. I don't see it present in all the tools, nor not always enabled by default. If you are using a tool with
disable comments, check whether it offers this feature and whether you have enabled it, as that could clean your codebase somewhat.

What this highlights is that supporting this feature leads to needing cleaning up features. If your linter doesn't have
that, I think it's a bit weird that it cleans up your codebase but doesn't clean up after itself. Kind of like a cleaner
that cleans your house while wearing dirty shoes.

## Why do people use disable comments in the first place?

I find that disable comments have a surprisingly prevalent place in some tools' documentation.
[`deno_lint`](https://lint.deno.land/)'s website goes as far as to only have 2 pages: the list of rules, and how to ignore them.

Most of the guides I see have dedicated pages for this feature, but only explain how to do it.

They don't go over why you'd want to use it, when you'd need to use it, and when it would be ok or not ok to use it.
**There is a lack of guidelines** for the user, and I think this has shown in the industry when you look at how people use—and create—these kinds of tools.

It feels to me like this feature gets added to the tool simply because it was in the other static analysis tool that
they know, reinforcing the feeling for the next one that it's an essential feature.

A type of comment that I've received several times about `elm-review` is: "Very cool and useful project. I think it would be a nice
addition if we could ignore errors through comments". Every time I received this comment I asked why they think it would be useful,
and I never got a good answer. Usually it's something like *"well... similar tools have it?"*.


### Why do users want disable comments

From experience, I find that people reach out for disable comments *way* quicker than they should, and often not for good
reasons. Let's go through those.

#### Prioritization

The first one is prioritization, when you acknowledge the reported issue but deem it too costly to resolve right now
(compared to delaying a bug fix or the release of a feature), pushing the fix for later. I am not the one to decide or
to judge or decide whether this is wrong or right, and I think this is likely necessary to some extent.

#### Not understanding the error or the solution

If you find that the message describing the issue is not clear or plain wrong, you will think that a there is a false
positive reported by the rule.

Often this can simply be an issue with the words chosen to convey the error, and rephrasing the message can make the
user approve of the error, resolving the issue appropriately instead of ignoring it.

Similarly, if the error does not suggest a solution—through automatic fixes or explanations in text— or formulates it in a
confusing way, then the user may not know how to resolve the issue and decide to ignore it.

For instance, instead of having an error saying 

> Forbidden onClick event handler on a div element

the author of the rule could go for something like:

> Forbidden onClick event handler on a div element.
> 
> Clickable divs make it impossible for some users to interact with the application, because screen readers don't expect
> divs to be interactive.
> 
> Instead, try to move the event handler to a button. Learn more at <good-resource-on-accessibility.com>.


A lot of the static analysis tools I see try to fit everything into a single sentence, often trying to make it as short
as possible which ends up being only slightly more informative that the rule name.

I find this unhelpful to users because it will often not convey enough information, and it may feel like
someone is shouting at you repeatedly and unhelpfully. More information is often available in the rule's documentation,
but unless it's linked by the tool, this explanation is likely only seen by the one who added the rule, not their
teammates.

In my opinion—[just like the Elm compiler](https://elm-lang.org/news/compilers-as-assistants)—static analysis tools
should be assistants, not adversaries.

In `elm-review`, every error is split into a short *message*—which is the same short and recognizable summary as above—and
additional *details* where the tool can give explanations on the error, the reasoning behind the rule, possible solutions,
useful insight that the rule uncovered and resources to learn more.

Mentioning these can make the experience much nicer for the user!

This requires for the tool to allow more than one line of text, otherwise the experience will be sub-par for the user,
and rule authors will likely not add more information than necessary.

#### Not agreeing with the rule

Sometimes an issue is reported to you, and you don't agree with what the rule is trying to forbid or enforce. I find
this to be most common with rules related to code style, which as you probably know can lead to heated debates.

**Tiny segue into code style:**
`elm-review` has very few rules related to code style, primarily because the community has adopted and embraced
a [code formatter](https://github.com/avh4/elm-format) early enough in the development of the language, before people
started to have strong opinions (well, that's how *I* think things played out at least). This means that we can ignore most of these concerns and focus on more impactful rules.
I strongly recommend checking out the code formatters for your language: they can help you and your team out more than
you think, and they are simply much better at handling this concern than a linter configured with dozens of stylistic
rules.
**End of segue**

In general, I would argue that rules that you don't agree to should not be enabled in the first place.

Deciding to enable a rule should be done as a team. If you can't get the buy-in of your teammates, enabling the rule
may create more problems than it solves. Err on the side of not enabling a rule by default rather than the opposite.

Of course, it's okay to try out a rule—when someone is sceptical but willing to be convinced, or when it looks like a
good rule from the description—but you as a team should be ready to disable the rule when you have tried it out
and noticed some problems. If people don't explicitly complain but you see a lot of disable comments, engage in a
discussion because there is likely some friction (because they don't agree or because of other problematic aspects).

`elm-review` has a whole section on
[when (not to) enable a rule](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/#when-to-write-or-enable-a-rule)
(or write them, since you can create custom rules), including a checklist that I think is worth going through:

```markdown
- [ ] I have had problems with the pattern I want to forbid.
- [ ] I could not find a way to solve the problem by changing the API of the problematic code or introducing a new API.
- [ ] If the rule exists, I have read its documentation and the section about when not to enable the rule, and it doesn't apply to my situation.
- [ ] I have thought very hard about what the corner cases could be and what kind of patterns this would forbid that are actually okay, and they are acceptable.
- [ ] I think the rule explains well enough how to solve the issue, to make sure beginners are not blocked by it.
- [ ] I have communicated with my teammates and they all agree to enforce the rule.
- [ ] I am ready to disable the rule if it turns out to be more disturbing than helpful.
```

I would advise against blindly adopting another team's configuration. Instead, for each rule, read its documentation and
decide whether you like it or not. `elm-review` rules by default have a section on "when (not) to enable this rule"
which should help you decide.

---

Again, giving the reasoning behind the rule or an explanation of what the rule is trying to prevent in the error's details
can help convince the one reading the error.

Coming across a rule that says `Forbidden use of Html.button` may leave one
thinking that it's a silly rule because there is nothing wrong with that function. But if your rule is custom-made and
you have control over the error details, then the following details can prevent them from ignoring the rule.

> Do not use `Html.button` directly
> 
> At fruits.com, we've built a nice `Button` module that suits our needs better. Using this module instead of `Html.button` ensures we have a consistent button look-and-feel across the website.

TODO screenshot of elm-review error.


#### False positives

A false positive is when the static analysis tool reports an error when it shouldn't in the given circumstances.

Sometimes a rule reports false positives because of a bug waiting to be fixed. While the fix has not been released, you
as a user might want to ignore the error so as not stay blocked, which I think is reasonable.

As far as I can imagine, there is only a single reason why a rule author would want to allow their users to use disable
comments (except allowing them to prioritize, not being blocked by a bug, etc), and that is to be able to ignore false
positives that the rule **purposefully** reports.

I don't mean that the rule author aims to report more errors than necessary. Rather, they are over-reporting as a means
to not under-report, which is where static analysis unfortunately get a very bad reputation of being annoying tools. The
reputation is so bad that one of the reasons people don't use static analysis tools **at all** is because
[there are too many false positives](https://people.engr.ncsu.edu/ermurph3/papers/icse13b.pdf). 


#### Knowledge coverage

TODO Could this be a post on its own?

From my point of view, false positives are mostly due to a lack of inferable knowledge from the project or because of
limitations from the tool. Let's go through examples of an environment with a low knowledge coverage.

##### Low knowledge coverage environment

Imagine that you are working in a dynamic language like JavaScript, and want to write a rule that removes all the
unnecessary calls to the [`Array#map`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/map)
method, like `value.map(b => b)`, which is equivalent to `value` on its own.

```js
function someFunction(value) {
    -- Unnecessary map to the value itself.
    return value.map(c => c);
}
```

The problem is that without more information, we can't be sure that `value` is an `Array` or not. Even if we assume the
function works as intended by the developer, we can't be sure that `value` is an `Array`. Maybe it is a custom construct
that happens to have a `map` method with an entirely different behavior. Maybe someone changed the standard behavior of
the `Array` map functions (by changing the prototype).

We could potentially look at all the call sites of the function to see if the argument is always an `Array`. That can be
hard to figure out, but it will be limited seeing as there is no JavaScript linter out there (AFAIK) that allows looking
at more than a single file at a time. That means we can't know how the function gets used in other files.

Maybe the `map` function is the `Array` one, but it is used to create a shallow copy of `value` because it will be
mutated by the parent function while needing the original argument to stay unchanged. Again, we could try to infer
whether applying this fix would change the behavior, but we'll hit the previous limitation of the tool again.

While the JavaScript linters could push the boundaries of their limitations by allowing rules to look at multiple files
at the same time, it's clear that the more possibilities the language provides, the less the language becomes inferable,
knowable and predictable. And that is true for both static analysis tools and for developers. (I mean, static analysis
tools are just code reviewers on steroids looking only at a set of specific things).

In this case, using TypeScript and add adding types would likely be sufficient, as it would increase the knowledge coverage.


##### High knowledge coverage environment

In Elm, `value.map(b => b)` is equivalent to `List.map (\b -> b) value` (`List` being sort of equivalent to a JavaScript
`Array`).

With the knowledge we have from the type of `List.map`, we know that `value` must be `List`.

Elm doesn't allow overriding functions, so we can be sure no-one changed the behavior of this standard function.

All values are immutable, so there is no concept that requires creating shallow copies of a value.

TODO create a section for everything that adds or removes knowledge?
The knowledge coverage gets reduced when your codebase or ecosystem uses macros, code replacements, introspection, ...
If somehow you can make your tool aware of what these do or how they work, then it might be okay. But I imagine this will be a lot of trouble.
It gets worse if the ecosystem allows certain kinds of macros, code replacements, introspection, ...


TODO Code generation is okay, as long as it gets included in the analysis of the tool. You can likely ignore all or most
errors (security issues would be useful to keep, code style not so much) that are reported in those files, but they
contain information that could be useful for other rules to know, such as what types and values are exposed in them.
If you can somehow provide a summary of what they contain, it might be enough for some rules.

What the dependencies of your project are is also useful information. If your static analysis tool can read the list of
the dependencies, then it can likely detect unused dependencies and other information that might be relevant for other
rules. If it can't know the dependencies because of how that ecosystem handles them, then your project becomes less
inferable.


I have wanted on multiple occasions to write `ESLint` rules that require the same knowledge as above and I had to
abandon the ideas because of the mentioned reasons.


TODO Don't put at the same level important errors and non-important errors. Make the important errors one report more
false positives and be locally disableable, and make the non-important ones (like the `map` example) not disableable but
also not report false positives. Having a non-useful `map` doesn't matter much, and it's not worth putting the user
the experience of having it. Instead, through different rules you can lead the user to bridge the knowledge gap. Such as
rules that require adding type information or JSDoc that would make it explicit what the type of something is.

ultimately in this case  will be limited  In this
case

Maybe `map` is used to construct a new reference 

If we report this and we're in these situations,
then we are pushing the user towards either changing the behavior of the function, which they will either do and
introduce a bug, or ignore the element

Maybe it is a `map`.


TODO SOmetimes a false positive gets ignored, but then later on it becomes a real positive?
TODO No distinction between temp ignored, false positive etc.

or because it's intentionally reporting false
positives in order to not have false negatives.

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

TODO If you take prebuilt configuration sets, then u can't customize the rules.

TODO Stop aiming for performance if you aren't able to do custom rules

TODO Example of stray and unnecessary disable comments


## Disable through configuration, and better alternatives

Instead, make your rules more configurable, or don't write them at all (sometimes they're simply bad ideas).

Give guidelines as to when it's okay to disable things.

Let each rule decide whether they can be disabled through comments? But don't make it the default. 

Allow rules to report configuration errors when the passed options are unexpected. Don't let the rule run with invalid premises.

Help them fix the issues with automatic fixes so that they can fix the issues quickly.

`elm-review` allows disabling a specific rule (or all rules) for specific files/folders, which I believe is much more powerful
than the common option of ignoring files/folders. This way, if you think a rule is very useful for production code, but
not that much for test code, then you can simply do `Rule.ignoreErrorsForDirectories [ "tests/" ] someRule`.

At some point, we will have a temporarily suppressed errors, to improve the [experience of gradual adoption](https://github.com/jfmengels/elm-review/discussions/47),
when you add a new rule to a codebase and it has a lot of errors but no automatic fix for instance.

Solution for vendored/generated code.
Solution for temporary disable.

Kudos to Go vet (https://github.com/golang/go/issues/17058)


TODO No difference between ignored elements temporarily due to a lack of time (remain to be resolved), and the ones that
are false positives (have been investigated). Both fall in the same category and will likely stay as is.

https://stackoverflow.com/questions/2891758/when-to-stop-following-the-advice-of-static-code-analysis