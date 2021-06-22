---
title: Knowledge coverage
date: '2021-06-15T12:00:00.000Z'
---

TODO Fog of war image: https://www.google.com/search?q=fog+of+war&sxsrf=ALeKk02wPAC0ldQg24hrKSp0zJCjelxaKA:1624305025337&source=lnms&tbm=isch&sa=X&ved=2ahUKEwiP26rgv6nxAhVXB2MBHWjaCAwQ_AUoAXoECAEQAw&biw=1848&bih=1073#imgrc=77FgFssSiS7MmM
TODO Computer vision: https://www.google.com/search?q=futuristic+computer+vision&tbm=isch&ved=2ahUKEwjEvPKQwKnxAhUNNBoKHUmGDt8Q2-cCegQIABAA&oq=futuristic+computer+vision&gs_lcp=CgNpbWcQAzIECAAQGDIECAAQGFCwgQJYu4gCYKGJAmgAcAB4AIABZ4gBswOSAQM3LjGYAQCgAQGqAQtnd3Mtd2l6LWltZ8ABAQ&sclient=img&ei=5-3QYIStCo3oaMmMuvgN&bih=1073&biw=1848#imgrc=oPTUMubLlT4GMM

TODO I have been wondering for a long time why `elm-review` feels like such a good tool, compared to similar tools in
other languages and ecosystems, and I think one of the main reasons is what I would call—for lack of a better term— the
**knowledge coverage** of the target language.

To me and from the perspective of someone deep into static code analysis, this refers to the amount of
information that you can extract or infer from a project. The more you can infer, the less false positives you will
report. And the less false positives you have, the more the users will be happy with the static analysis tool (henceforth shortened to SAT).


##### Low knowledge coverage environment

Imagine that you are working in a dynamic language like JavaScript, and want to write a rule that removes all the
unnecessary calls to the [`Array#map`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/map)
method like `value.map(b => b)`, which is equivalent to `value` on its own.

```js
function someFunction(value) {
    -- Unnecessary map to the value itself.
    return value.map(c => c);
}
```

The problem is that without more information, we can't be sure that `value` is an `Array` or not.

Maybe it is a custom construct that happens to have a `map` method with an entirely different behavior. It is also
that someone changed the standard behavior of the `Array.map` function by changing the prototype of `Array`.

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

TODO code evaluation
TODO dynamic code paths
TODO validation-less trust of external data

## Elm - a knowable language

`Elm` is a fairly simple language. It has few constructs and has a set of imposed constraints, such as all values are
immutable and nothing can provide side-effects.



## Consequences

TODO: No false positives -> No disable comments.

#### Knowledge coverage

From my point of view, false positives are mostly due to a lack of inferable knowledge from the project or because of
limitations from the tool. Let's go through examples of an environment with a low knowledge coverage.


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

TODO Having a consistent ecosystem also helps a lot. If your ecosystem has multiple ways that are radically different to
manage your dependencies, to build your tools, each with different results or semantices, it becomes a lot harder for
maintainers of a static analysis tool to do the job properly. If you're evaluating a language with features that can be
enabled or disabled at compile-time, then that is information that you need to share with your SAT. And the SAT needs to
stay up to date and maintain what can become a very complex system.
Elm has an integrated package manager, it is the build tool for everything that relates to Elm code, etc. Only one thing
to handle


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