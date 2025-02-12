---
title: The omniscient linter
content/blog/the-omniscient-linter/index.md
published: "2023-08-13"
---

> Omniscient
> 1. having infinite awareness, understanding, and insight
> 2. possessed of universal or complete knowledge
>
> https://www.merriam-webster.com/dictionary/omniscient

Let's imagine an omniscient linter, which had knowledge of your entire codebase, of its entire Git history, of everything related to your product's needs and even of the minds of your developers, current and previous.

Basically, that linter is as knowledgeable about a codebase as an omniscient God (or the idea that people have of such an entity).

Now, my question is: given such a linter (and let's imagine it's without bugs), can you imagine this linter reporting an error when it shouldn't?

Would there ever be a problem that it reports that isn't actually a problem? But also, would there ever be a piece of code somewhere with a problem that the linter would not report?


Feel free to think about this for a minute.

---

Personally, I am having a hard time imagining these situations. If my linter is implemented correctly and has full knowledge of pretty much everything, then it will always be correct and never miss anything.

The only things I can imagine it missing are problems that it is not looking for (because the rule does not exist or has not been enabled).

In practice, linters are known for reporting a lot of false positives and missing a lot of problems. And the contrast between the picture I painted earlier and reality in my opinion comes down to the fact that linters are not omniscient. Or more specifically, they lack information.

My premise is that any piece of information you give to your linter can make it more powerful and accurate. And I've applied this idea to make [`elm-review`](https://elm-review.com) (the linter that I created) much more precise and powerful than it was before.

I want to go through a few examples where this is true, and where I believe the future of linters is.

## Type information

I used to lint JavaScript code a lot a few years ago, and I decided against writing a lot of rules I had in mind because they would be too inaccurate, leading to many false positives.

A recurring problem was the lack of type information in dynamic languages. Let's say we have this piece of JavaScript code:

```js
let array = [ 1, 2, 3 ];
let newArray = array.map(n => {
  n + 1;
});
```

You might expect the value of `newArray` to be `[ 2, 3, 4 ]`, but it is `[ undefined, undefined, undefined ]`. Why? Because there is no return statement, which makes the return value implicitly be `undefined` (the `n + 1;` has no effect without a `return`).

So obviously we would like to have a tool tell us about this obvious mistake. And there is! ESLint has [a rule exactly for this](https://eslint.org/docs/latest/rules/array-callback-return).

Unfortunately, it won't work flawlessly, as explained by a note at the bottom of the [documentation](https://eslint.org/docs/latest/rules/array-callback-return#known-limitations):

> This rule checks callback functions of methods with the given names, *even if* the object which has the method is *not* an array.

That means that something that has a `map` method that looks too much like an Array's `map` method will be reported, even if it's not the same.

```js
notAnArray.map(element => {
  doSomething(element);
});
```

The problem here is lacking type information: if we had a way to know whether an expression was an Array or not, and we made the rule use that information, then there would not be an error where there shouldn't be. Thankfully in this case, this should be pretty rare.

But this is a pretty common problem, especially for dynamic languages. If the tool had type information, then it would be correct all the time (or at least way more often).

## Manifest files

I call manifest files all the files that detail the core structure of a project and its dependencies. For Elm, that's going to be `elm.json`, whereas for JavaScript projects the thing that comes closest is the `package.json` file.

The information in those files are core to the project, and being able to inspect it means you get free access to that information. I see a lot of linters that don't look at those files and makes their users reconfigure the linter/rules with duplicate information.

That leads to configuration errors because of [accidental configuration](https://youtu.be/XjwJeHRa53A?t=1447) that are hard to figure out and correct.

## Contents from other files

I have dedicated a whole blog post about [multi-file analysis](/multi-file-analysis) and what that enables.

Being able to inspect contents of other files make it possible to gather an enormous amount of insight that reduce the number of false positives and makes a lot of rules viable.

## Contents from other files of a different language

Linters usually focus on a single language to analyze, but I find it limiting to think that a project consists only of files written in the same language. A lot of complex projects (especially commercial projects) are written using several languages.

Let's take the example of CSS and HTML (also works for CSS+JavaScript). Let's imagine in your project you write CSS classes and reference them in your code:

```html
<button class="btn delete-btn">Delete</button>
```

```css
.delete-btn {
	background-color: red;
}
.some-other-class {
	// ...
}
```

There are at least two things that I find worth looking at:
1. Is the HTML referencing any non-existing CSS classes? That would likely be a problem.
2. Does the CSS define any classes that are never used in the HTML code? That would likely mean unused code that should be cleaned up.

To know either of these things, you need to look at both the HTML/JS **and** CSS files. So if you're using a JavaScript linter that only looks at JavaScript files but doesn't look at CSS files, then that's not going to be able to help you with either of these problems.

If you're using a utility-based library like Tailwind instead, you still have similar problems. For instance to know whether you're using a non-existing class, you want to know which CSS classes become available from your Tailwind configuration, so you'd want to have access to either the generated CSS or interpret your Tailwind configuration to get the same knowledge.

In some cases, you could configure the tool to have that knowledge, but that may come with configuration problems, like the configuration being out of sync with the external knowledge.

In `elm-review`, I'll be adding support to look at arbitrary non-Elm files. Some early use-cases that I'm thinking of looking into is the CSS problems above. Another one is being able to look at the `CHANGELOG.md` file and noticing whether it's up-to-date with the version defined in the `elm.json` manifest.

## Knowability of the language

When statically analyzing code, one thing that makes a lot of difference is how easy or how hard that language is to analyze.
Unfortunately, it is hard to do much about that, except switching from one programming language to another.

I have done that as I went to using/analyzing JavaScript to using/analyzing Elm, and the analysis is **so, so much easier**.

I have a [whole talk](https://www.youtube.com/watch?v=_rzoyBq4hJ0) on the subject. The people who can do most about this are the language designers who can design the language to be more explicit and (probably a big factor) less dynamic.

## Afterword

These are all paths that make it easier for tools to gain the knowledge they need in order to be more accurate and more powerful.
I have added support for most of these and plan to add the rest in the future.
In the initial versions of my tool, it had very few of these pieces of information, and it was practically unusable without a lot of false positives.
Once I extended that, the tool became a lot more interesting to use, to the point where a lot of people tell me `elm-review` is now the most reliable linter that they've used.

I hope this inspires other linter authors to go in the same direction.