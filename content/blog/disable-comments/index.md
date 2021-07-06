---
title: How disable comments make static analysis tools worse
date: '2021-07-05T08:00:00.000Z'
---

```js
/* eslint-disable -- TODO get rid of the annoying rule about camel casing variable names!!! */
if (!(shopping_cart.total = 0)) {
    processPayment(shopping_cart.total, payment_info);
}
unlockItems(shopping_cart.items);
```

Seeing disable comments in code has always made me feel uneasy. Whenever I encounter one, a bunch of questions pop into my head. What kind of
error did the static analysis tool report? Was it something that didn't apply? Why did the developer choose to
ignore it? Were they being lazy? Did they understand the error? What is the risk of keeping it ignored? **If it's
being ignored, why is the rule even enforced?**

In [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/), the static analysis tool I designed
for [Elm](https://elm-lang.org/), I decided to not include the widespread feature of allowing disabling reports through
specific comments.

I will argue in this article that disable comments and warnings are harmful to static analysis tools and our codebases,
and ultimately argue that configurability and precision of rules can solve the problems that disable comments were trying to solve.

I'll split the article into several sections:
- [What are disable comments, and what is wrong with them?](#what-are-disable-comments-and-what-is-wrong-with-them)
- [Why do we use disable comments and why do tools support them?](#why-do-we-use-disable-comments-and-why-do-tools-support-them)
- [What better alternatives can we use?](#what-better-alternatives-can-we-use)


## What are disable comments, and what is wrong with them?

"Disable comments" are comments that you can find in the source code that disable the reports of a static analysis tool
for some section of the code and for some specific "rules" (sometimes named "checks"). Some tools give it a different name, but I'll go with this naming for the rest of the article.

They are usually available in multiple flavors (each of the following examples is from a different tool, each of them
supporting most of the flavors).

- Disable for a single line (`ESLint` for JavaScript, `Pylint` for Python)

```js
function fn() {
    x = 1;
    return x;
    // eslint-disable-next-line no-unreachable
    x = 3;
}é
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

- Disable for entire files (`deno_lint` for `JavaScript`)

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

### The intrinsic issues with disable comments

There are several problems with the usage and enablement of disable comments.


#### Disabling rules that should never be disabled

At one of my previous jobs, we once left a `console.log` in our Node.js backend code in production which sent
sensitive information to our log management system such as secret keys.

These then showed up in our logs, and we had to remove them manually. I might be misremembering or exaggerating, but I
_think_ we had little control over our logs and we could not delete individual logs, only delete all the logs.
So that was a fun day.

To never have this happen again, we wrote an `ESLint` rule to forbid logging values known to contain
sensitive information. From that point on, it became impossible for that code to go to production. Or was it?

Well, no. It was still possible to write that problematic code along with disable comments ignoring that rule. It thankfully didn't
happen again (while I was there at least), but **why should it even be possible?**

There was no instance where we would ever want to allow this kind of code, yet there was no way to tell the tool to not allow
disabling the rule.


#### Overly greedy disable comments

Sometimes these disable comments are used in a way that disable *all* rules instead of just the few
that reported problems. There are some instances where you may not want the tool to report anything that is probably
appropriate (vendored code for instance) but this would be a suboptimal solution in my opinion (but more on that later).

Disable all comments are sometimes used in places where there are too many rules—that are "okay to ignore"—
reporting errors, and listing them all would be annoying.

The problem is the code covered by the comment can later change and contain important problems (from "not okay to ignore rules")
that will then not be reported. To avoid any bad surprises, it is much better to list the rules to disable than to disable all.

In the code excerpt I put at the very beginning (and pasted again below), it looked like a developer was getting frustrated with a rule that
enforced a certain convention in naming variables, and disabled the rule. While doing so and because they didn't specify
which rule, they also disabled all other rules, potentially until the end of the file, including one reporting that you
should not assign variables in conditions, as that is a common error and typo.

```js
/* eslint-disable -- TODO get rid of the annoying rule about camel casing variable names!!! */
if (!(shopping_cart.total = 0)) {
    processPayment(shopping_cart.total, payment_info);
}
unlockItems(shopping_cart.items);
```

In the code above, the total above would always be considered 0, and it would never charge the user money before giving
them access to the items they wanted to purchase. Your customers will be very happy though!

I wrote a rule to [forbid](https://github.com/sindresorhus/eslint-plugin-unicorn/blob/main/docs/rules/no-abusive-eslint-disable.md)
 [disable all comments](https://github.com/sindresorhus/eslint-plugin-unicorn/pull/33) back in my `ESLint` days. In `ESLint`'s case, not
specifying which rule to disable means disabling all the rules, which is I think a bad default behaviour.
Make the nice things easy and the bad things harder, not the opposite.

I found many places where this kind of disable comment was used where listing specific rules would have been better.
They would be caught by the rule I wrote, but I don't expect this rule to be enabled in most projects that use `ESLint`
since it's not part of the core rules or tool, and therefore not enabled by default. This pushes additional work to the
user.

I found when writing this article that someone from the `ESLint` core team later created
[a separate `ESLint` plugin](https://mysticatea.github.io/eslint-plugin-eslint-comments/rules/no-use.html) that does the
same thing along with 8 more rules around disable comments. To me, this is a sign that this feature can be misused in
plenty of ways that the authors are not comfortable with.


#### Unnecessary disable comments

Some tools will report when disable comments are used that don't suppress anything anymore, usually because the code
it covers has since changed. I don't see it present in all the tools, and then not always enabled by default.

If you are using a tool with disable comments, check whether it offers this feature and whether you have enabled it, as
that could clean your codebase somewhat.

What this highlights is that supporting this feature leads to needing clean up features. If your tool doesn't have
that, I think it's a bit weird that it cleans up your codebase but doesn't clean up after itself. Kind of like a cleaner
that cleans a room while wearing dirty shoes.


#### Original intent is lost

We will go through this in later sections, but the reason *why* a disable comment was used is from experience rarely
explained next to the comment.

Sometimes these comments are done to temporarily ignore an issue, and sometimes they're here for legitimate reasons,
like the rule reporting a false positive.

For the developer adding the comment, it's crystal clear why they chose to do it. For later readers of the code, it will
likely be a lot more question-inducing.

A future reader may skip over a disable comment, but they may also wonder whether the disable comment was intended to be
temporary or whether it's there for legitimate reasons. Potentially they'll then try to remove it to see what kind of
error is being disabled, which is likely distracting from the work they intended to do in the first place.
I'm this kind of future reader.

I think it's an issue that the same disable comment is used for both situations without a way to distinguish them or to
look for them once someone wants to clean up all the temporary comments.

It doesn't help that almost none of the tutorials I see about how to use disable comments even suggest leaving a comment
to explain why.

Kudos to the tools that at least require something that looks like an explanation from the developer.


### Warnings

Another widespread feature of static analysis tools, that also allows disregarding the output of the tool, is the
ability to mark some errors as **warnings** using severity levels.

The most common severity levels I see are "errors" and "warnings", where the former makes the tool exit with an error
code and make your test suite fail, and the latter will show the problems but will allow these to remain.

I think that users often associate the warning severity with rules that are okay not to fix. So if
a rule has a lot of false positives, they think it should have a warning severity. I believe that is naive and that
warnings are more harmful than that.

From my experience, when the severity is set to "warning", the reported issues will sometimes be fixed, and sometimes not.
They will start piling up, and users will see an increasingly bigger wall of warning reports, where it becomes
harder and harder to spot new and useful warnings.

When the day comes when no one on the team will dare to look at them anymore, the team will likely resort to drastic
measures: doing a cleanup pass (by solving the issues or adding disable comments) or disabling the rules. And in the
meantime, avoidable bugs may have slipped in.

When you configure your tool, you choose a set of rules to enforce. Yet **warnings are for rules that are not enforced.**

Maybe the tool authors would disagree, but it's hard to tell because just like for disable comments, there rarely are
documented guidelines on when to use one severity over another. In fact, from the set of tools I've researched for this article, I
have not been able to find any other explanation for warnings beyond the not so helpful "warnings will not make the tool
exit with an error code".

`elm-review` doesn't have severity levels, meaning that all enabled rules are enforced.
Yes, no warnings and no disable comments. And it works well.

For the rest of the article, whenever I mention "disable comment", I will mean either using a disable comment to suppress
the report or enforcing the rule as a warning and not addressing the reported issues. In practice, these are very similar.


## Why do we use disable comments and why do tools support them?

I find that disable comments have a surprisingly prevalent place in some tools' documentation.
[`deno_lint`](https://lint.deno.land/)'s website goes as far as to only have 2 pages: one with the list of rules, and
one on how to ignore them.

Most of the guides I see have dedicated pages for this feature, but only explain how to do it.

They don't go over why you'd want to use it, when you'd need to use it, and when it would be ok or not ok to use it.
**There is a lack of guidelines** for the user, and I think this has shown in the industry when you look at how people use—and create—these kinds of tools.

It feels to me like this feature gets added to the tool simply because it was in the other static analysis tool that
they know, reinforcing the feeling for the next one that it's an essential feature.

A type of comment that I've received several times about `elm-review` is: *"Very cool and useful project. I think it would be a nice
addition if we could ignore errors through comments"*. Every time I receive this comment I would ask why they think it would be useful,
and the typical answer is something like *"well... similar tools have it?"*.


### Why do users want disable comments?

From experience, I find that users reach out for disable comments *way* quicker than they should, and often not for good
reasons. Let's go through those.

#### Prioritization

The first reason is prioritization: when you acknowledge the reported issue but deem it too costly to resolve right
now—compared to delaying a bug fix or the release of a feature— pushing the fix for later.

I am not the one to decide or to judge whether this is wrong or right, and I think this is likely necessary to
some extent.

#### Not understanding the error or the solution

If you find that the message describing the issue is not clear or plain wrong, you will think that there is a false
positive reported by the rule, or simply feel like not dealing with it right now.

Often this can simply be an issue with the words chosen to convey the error, and rephrasing the message can make the
user approve of the error and then resolve it, instead of ignoring it.

Similarly, if the error does not suggest a solution—through automatic fixes or explanations in the message— or formulates it in a
confusing way, then the user may not know how to resolve the issue and decide to ignore it.

For instance, instead of having an error saying 

> Forbidden onClick event handler on a div element

the author of the rule could go for something like:

> Forbidden onClick event handler on a div element.
> 
> Clickable divs make it impossible for some users to interact with the application because screen readers don't expect
> divs to be interactive.
> 
> Instead, try adding the event handler on a button. Learn more at <good-resource-on-accessibility.com>.


A lot of the static analysis tools I see try to fit everything into a single sentence, often trying to make it as short
as possible which ends up being only slightly more informative than the rule name.

I find this unhelpful to users because it will often not convey enough information, and it may feel like
someone is shouting at you repeatedly and unhelpfully. More information is often available in the rule's documentation,
but unless it's linked to by the tool, this explanation is likely only seen by the one who added the rule, not their
teammates.

**Static analysis tools should be assistants, not adversaries.**

In `elm-review`, every error is split into a short *message*—which is the same short and recognizable summary as above—and
additional *details* where the tool can give explanations on the error, the reasoning behind the rule, possible solutions,
useful insight that the rule uncovered, and resources to learn more.

Mentioning these can make the experience much nicer for the user!

This requires the tool to allow more than one line of text though. Otherwise, the experience will be sub-par for the user,
and rule authors will likely not add more information than necessary.

Maybe the message is kept short in some tools because the authors expect their users to have a lot of unaddressed warnings, which makes
it a lot harder to find the new reported warnings. I'd argue that if all reported errors are worth addressing (more on
that in later sections) then this is not a problem.


#### Not agreeing with the rule

Sometimes an issue is reported to the user, and they don't agree with what the rule is trying to forbid or enforce. I find
this to be most common with rules related to code style, which as you probably know can lead to heated debates.

**Tiny segue into code style:**
`elm-review` has very few rules related to code style, primarily because the community has adopted and embraced
a [code formatter](https://github.com/avh4/elm-format) early enough in the development of the language before people
started to have strong opinions (well, that's how *I* think things played out at least). This means that we can ignore most of these concerns, and focus on more impactful rules.
I strongly recommend checking out the code formatters available for your language: they can help you and your team out
more than you think, and they are simply much better at handling this concern than a linter configured with dozens of
stylistic rules.
**End of segue**

In general, I would argue that rules that you don't agree with should not be enabled in the first place.

Deciding to enable a rule should be done as a team. If you can't get the buy-in of your teammates, enabling the rule
may create more problems than it solves. Err on the side of not enabling a rule by default rather than the opposite.
Of course, you should try to convince your colleagues if you think the rule brings value, but succeeding at it is important.

It's okay to try out a rule—when someone is sceptical but willing to be convinced, or when it looks like a
good rule from the description—but you as a team should be ready to disable the rule when you have tried it out
and noticed some problems.

If people don't explicitly complain but you see a lot of disable comments, engage in a
discussion because there is likely some friction (because they ultimately don't agree or because of other problematic aspects).

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

Just like the last step of the TDD cycle, I feel like the step of re-evaluating a rule and potentially disabling
it is often forgotten.

---

Again, giving the reasoning behind the rule or an explanation of what the rule is trying to prevent in the error's details
can help convince the one reading the error.

Coming across a rule that says `Forbidden use of Html.button` may leave one
thinking that it's a silly rule because there is nothing wrong with that function. But if your rule is custom-made and
you have control over the error details, then the following details can prevent them from ignoring the rule.

> Do not use `Html.button` directly
> 
> At fruits.com, we've built a nice `Button` module that suits our needs better. Using this module instead of the more
> general `Html.button` ensures we have a consistent button look-and-feel across the website.


### False positives

Lastly, a user might use a disable comment when they think they've encountered a false positive from a rule.

A false positive is when the static analysis tool reports an error when it shouldn't in the given context.

Sometimes a rule reports false positives because of a bug in the code—just like in any other product—waiting to be fixed.
While the fix has not yet been released, a user might want to ignore the error so as not to stay blocked, which I think is reasonable.

As far as I can imagine, there is only a single reason why **a rule author** would want their users to use disable
comments (except allowing them to prioritize and not being blocked by a bug), and that is to allow them to ignore false
positives that the rule **purposefully** reports.

I don't mean that the rule author aims to report more errors than necessary. Rather, they are choosing to over-report
(false positives) as a means to not under-report (false negatives), because it is hard or impossible for the rule to
distinguish between the two in some cases.

Reporting too many false positives is where static analysis tools, unfortunately, get a very bad reputation of being annoying
tools, to the point that it's an often-cited cause for people not to use them at all.

(From here on out, "false positives" will not refer to false positives caused by bugs in rules.)

## What better alternatives can we use?

I think there are several ways to make our static analysis tools better, without using disable comments, or by using
them better.

We will revisit configuration systems:

- [Non-disableable rules by default](#non-disableable-rules-by-default)
- [Fine-grained rule configuration](#fine-grained-rule-configuration)
- [Distinguishing between temporarily ignored and permanently ignored](#distinguishing-between-temporarily-ignored-and-permanently-ignored)
- [Configurable rules to bridge the knowledge gaps](#configurable-rules-to-bridge-the-knowledge-gaps)

and then rethink how and when to write rules in order to have fewer false positives.

- [Aggressive and relaxed rules](#aggressive-and-relaxed-rules)
- [Make the environment more knowable](#make-the-environment-more-knowable)
- [Forbid constructs that lead to false results](#forbid-constructs-that-lead-to-false-results)
- [Don't implement the rule](#dont-implement-the-rule)

### Revisiting the configuration system

#### Non-disableable rules by default

Even if you think your tool can't live without disable comments, I would argue that rules should at least not be disableable by
default. I think that it should be an opt-in setting for every rule, as I don't imagine many users would choose to opt out.
Though for existing tools, allowing to opt out would make for an easier first step.

I mentioned a custom rule [earlier](#disabling-rules-that-should-never-be-disabled) that my team would never allow to be disabled (the people involved
in creating the rule at least). If we could specify in our configuration that no one could disable the rule, we would sleep a lot
tighter. We would only have to make sure no one changes the configuration for this rule, instead of having to monitor
every commit being added to our project.

Having it be shown in the configuration (or in a Git diff) that someone made a rule disableable can be a good start for a
conversation on how to do things better instead.

Ok, this was not a way to reduce the number of false positives, but I still think it would be a valuable improvement to
any static analysis tool that supports disable comments.


#### Fine-grained rule configuration

I believe that one reason we see a lot of disable comments is because there are plenty of rules where a pattern is
forbidden but is considered acceptable in specific contexts or locations, but the configuration system of the tool
doesn't allow specifying this. Therefore, users reach out for disable comments.

`elm-review` allows disabling a specific rule for specific files/folders.

This way, if you want to forbid something generally but allow it in a centralized place, then you can make that explicit
in the configuration instead of allowing it through disable comments. It can show teammates where a pattern is acceptable and
where they should add related functionalities.

For the `Html.button` rule mentioned earlier, you could write

```elm
config =
    [ NoHtmlButton.rule
        |> Rule.ignoreErrorsForFiles [ "src/OurCustomButtonModule.elm" ]
    -- and then some other rules...
    ]
```

I didn't mention it yet, but `elm-review`'s configuration is written in Elm code. It would work also for JSON/YAML-like configuration systems though.

If you think a rule is very useful for production code, but not that much for test code, then you can
do `Rule.ignoreErrorsForDirectories [ "tests/" ] someRule`.


```elm
config =
    [ someRule
        |> Rule.ignoreErrorsForDirectories [ "tests/" ]
    ]
```

I would highly advise leaving comments where these `ignore*` functions are used to explain why they were used, but the
configuration system needs to allow comments (which is harder in `JSON` for instance).

This system doesn't work well with prebuilt configuration sets, because it is cumbersome to
customize the rules to fit the needs of the project better. But as I pointed out earlier, you should probably not re-use someone's configuration anyway. Copy-pasting a
configuration and manually re-evaluating each rule would be a better alternative in my opinion and would work better with this
kind of system.


#### Distinguishing between temporarily ignored and permanently ignored

A flaw of disable comments is that there is no distinction between what is "temporarily" ignored so that someone can
ship a feature before a deadline, and what is "permanently" ignored.

When the disable comment contains a reason for its use, humans can read them and understand in which situation it was
used. From experience, I find that an explanation is rarely present. Also, the static analysis tool won't be able to
understand it and help you clean it up if appropriate.

I believe that being able to make this distinction is important.

Not yet but likely sometime in the future, `elm-review` will support a system that allows temporarily suppressed errors.
The idea is that when you are adding a rule or need to unblock yourself temporarily, you can generate a file that puts
all the reported errors in an ignore list that is explicit and visible (so that any addition is readable in a Git diff).

The tool would then block you when you introduce a new error, give you some tools to help you clean up, tell you to
re-generate the list of exceptions when you have fixed an error, and give you reminders when there are still some remaining.

In short, the system would allow you to incrementally fix the previously ignored errors, while still preventing new ones
from creeping into the project.
Having a list of issues in a file or shown by the tool makes it easier to know what to go clean up once that new feature
you've been working on has been released and you have a bit more time.

Maybe this system makes it too easy to ignore something and maybe it's not a great idea. At this point, I can't
tell for sure. Feel free to go through the [proposal](https://github.com/jfmengels/elm-review/discussions/47) if you're curious.

If you like the idea, there is already a tool called [Betterer](https://dev.to/phenomnominal/betterer-v1-0-0-301b)
that does pretty much the same thing and integrates well with seemingly any tool. For now, I prefer to go with a built-in
solution which I think will give a better experience for the user, but it might very well be enough for you.

I know that some people tend to add rules as warnings so that they can gradually adopt a rule until all warnings have
been addressed, and then enforce the rule with an error severity. If you do it the same way, then this approach would
work better because it would prevent new errors from creeping in while the rule is a warning.


#### Configurable rules to bridge the knowledge gaps

False positives are in a lot of cases due to a lack of inferable knowledge from the project or because of
limitations from the tool, or because the rule can't guess the intent of the developers.

To reduce the number of false positives, one solution that you can go for is allowing the rule to receive configuration
so that the user can supply some of the missing information that the rule doesn't have.

For instance, this [`elm-review` rule](https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/NoUnused-CustomTypeConstructors)
has a limitation in its ability to know what types have
["phantom type variables"](https://ckoster22.medium.com/advanced-types-in-elm-phantom-types-808044c5946d), and imperfect
knowledge here can lead to false positives.
The rule can determine this just fine for types defined in the project, but it can't figure it out for types that
come from dependencies because `elm-review` doesn't (yet?) read into the code from the dependencies (it provides a summary
of the contents of dependencies which is sufficient in most cases).

In order not to have users use a disable comment, the rule allows users—through the means of configuration—to specify what types
from dependencies have phantom type variables, which fills all the knowledge gaps the rule previously had.

The next time the user writes similar code, there won't be a need to add a disable comment because the rule will
time already have sufficient knowledge, which beats multiplying the number of disable comments.

### Rethinking rules

#### Aggressive and relaxed rules

I think it's fair to have certain types of rules report false positives, such as rules that can prevent
security issues. But critical rules and non-critical rules should not be set to the same standard.

Critical rules could be made aggressive, meaning that they report false positives and that their false positives can be
disabled through disable comments.

Non-critical rules on the other hand should be relaxed: they should report no false positives (a few false
negatives would be okay) but should not be disableable through comments. If there are no false positives and you want to
enforce the rule, there is little reason to allow disabling it. 

For instance, code simplifications that may improve performance a tiny bit or are related to code style should probably
not lead your users through the experience of handling false positives. If your users do care about these a lot, maybe
you can make the rule configurable to allow them to toggle between an aggressive and a relaxed behavior.

Except in environments that have a lot of security issues or a lot of possible crashes, I think that most rules should
lean towards the relaxed side.


#### Make the environment more knowable

As said before, I think that a lot of the false positives come from the fact that we can't infer some
necessary information from the project.

Some languages and environments are harder to understand than others. Using a dynamically typed language, using
mutations, using implicit code constructs, using macros, using introspection, a lack of standards or conventions, etc.
All these make your language harder to inspect.

Because of that lack of information, rule authors are bound to make assumptions that can end up being wrong. Note that the same thing
happens for false negatives, the result mostly depends on the assumption the author makes and how strongly they hold on to it.

This means that if the project is easier to understand, your static analysis tool can report fewer false positives and make more powerful analyses, which I show for instance in
[safe dead code removal in a pure functional language](/safe-dead-code-removal).

I feel very lucky that I have [Elm](https://guide.elm-lang.org/) as a target language. The language is so simple
(there are very few constructs to learn and to analyze), explicit about everything, prevents so many types of errors
through its compiler, and usually has an explicit environment (we know the contents of dependencies, the list of source files, etc.).

Compared to when I was writing static analysis rules for untyped JavaScript, I am able to write so many more rules! Yet I
also **need** to write a lot less of them, because there is an excellent compiler already handling a lot of these issues.

Ok, I say this while knowing full well that you are not going to change your current tech stack because of this piece of
advice. But please somehow keep this in the back of your mind when you decide on using a language, or design one!

But even without changing your entire environment, you can maybe help your tools out with tiny changes.

When working with JavaScript, I remember I once wanted to forbid certain usages of specific methods on arrays. Let's imagine
I wanted to forbid `value.map(b => b)`, which is an unnecessary operation. The problem with this dynamic language is that I
have no way of knowing whether value is actually an `Array` or not. If it's not but assume it is one, that's a false
positive right there.

But if somewhere in the code you included type information—using TypeScript, types written in a function's documentation; heck, even in
simple comments!—then your tool could understand that and use it, which may save you a few false positives or false
negatives. You might still get those if your comments are outdated, but that's not a bad thing to be made aware of.

To be honest, I don't know of any such tool or rules that make use of this kind of additional information that is not
part of the language's specification (but I haven't done much research). I imagine it would require strong conventions and buy-in
from both the rule/tooling authors and the community that uses the tool. But if you write a custom rule for your project,
maybe this is enough for a specific use case.

Or maybe you can somehow let your tool know through configuration that you have forbidden certain dangerous or confusing
constructs in your project, and that it, therefore, doesn't have to be wary of those.


#### Forbid constructs that lead to false results

When a rule can't figure out whether something is a potential problem or not due to how the code is written, a trick it
can use is to report an error explaining that it can't figure out whether there is a potential problem in the code that
it's analyzing or not. And then in the error message, ask and explain how to—and this needs
to be very clear to your users—change the code in a way that will make the rule work flawlessly.

I have a custom rule enabled at work that reports unused CSS classes: it reads the list of CSS classes defined in CSS
files, then goes through all the Elm source files, and reports the unused classes. In Elm, those classes are marked as used when
being passed to the `class` function (and some friends), like `class "some-class"`.

But when the rule sees `class ("thing-" ++ modifier)`, where `modifier` is a parameter to the containing function, it
can become really hard to know what the used classes are. In some cases, we could maybe figure all the possible values of
`modifier`, but in more complex cases it would be too hard.

So what the rule does is report an error when `class` is used with anything else than a string literal, with a detailed
explanation asking the user to adapt their code to that requirement. Once all the code has been changed to code that the
rule can understand, we can report all the unused CSS classes with very high confidence.

This technique works surprisingly well, especially for custom rules. However, the guarantees that the rule provide need
to outweigh the effort. If the requested change is trivial and makes the code better
anyway, then I think users will comply most of the time. If it requires more effort, then the value the rule brings
needs to be high enough to warrant the effort, such as giving useful guarantees about the project.

I think it works especially well in `elm-review` because disabling the rule locally is not an option. Users either have
to follow the guidelines of the tool (like they would for a compiler error) or disable the rule entirely.

For the unused CSS classes rule, the upfront migration cost was definitely not zero, but the cost for next developers who
are already used to this explicit code is minimal. In return, the rule guarantees us that we have no unused CSS code in
the codebase and it helped us remove thousands of lines of CSS, which we found was definitely worth the effort. Also, it
made the code more explicit and predictable.

If you are interested, I described another application of this in [Safe unsafe operations in Elm](/safe-unsafe-operations-in-elm).


#### Don't implement the rule

If the rule does not report critical issues and you as the author can't figure out how to remove false positives, it
may be worth exploring another solution: not implementing the rule at all. Or disabling it if you're not the author.

Once we learn how to use static analysis tools to solve our problems, our view becomes more biased towards using them.
They are great tools, don't get me wrong, but it's also not a silver bullet. Just like any other tool, it has
situations where they are great, situations where they wouldn't help at all, and situations in between where they would
help but bring even more pain and frustration.

It's not worth adding a rule to make some things consistent if the rule will be disabled half of the time. False
positives can lose the trust the user previously put in the tool.

For the rules I personally contribute to my community, I set the requirement bar for implementing a rule really high.
The result is that maybe not everything is entirely consistent, but the trust people put into `elm-review`, and my rules,
is really high as well.

I believe that the trust users put in my tool give them additional energy to comply with what the rules ask them
to do, instead of reaching for disable comments or hacky workarounds.

That said, even when it's not a good idea to enforce a rule, they can still be very useful to discover potential
deficiencies or inconsistencies in a codebase which you can then fix as a one-time sweep. It will just be less useful
because issues can creep back in when you don't enforce it.


## Summary

I believe that disable comments have played the role of a crutch in the static analysis tool world, which have relied on
them instead of looking for better solutions and environments.

I hope you've seen how much room there is for improving them. I love static analysis and I want to see this field bloom.
I hope the ideas I presented here will resonate with tool authors. And tool users, I hope I have convinced you of
better ways to use them as well.

Thanks to Phill Sparks, Heyleigh Thompson, Evan Czaplicki and Dillon Kearns for reading through the drafts!