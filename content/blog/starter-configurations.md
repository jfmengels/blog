---
title: Starter configurations for elm-review
date: '2022-04-26T12:00:00.000Z'
---

One of the more recurring complaints I have heard about `elm-review` is that it is hard to get started with it. You have
to run `elm-review init`, find `elm-review` packages and add them and their rules one by one to your configuration.

When your mind is on building a cool thing, this is not something you wish to spend time on, even if you love `elm-review` as much as I do.

While I still believe it's very important for users to not blindly adopt rules or their configurations, and to make
a deliberate choice on [(not) enabling a rule](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/#when-to-write-or-enable-a-rule),
I agree that it can be a bit painful to set it up again and again.

In practice, I usually copy-paste the configuration from another project of mine when I start a new one.
Except for `elm-review` package projects, where `elm-review new-package` does that for me and more.

Today, I'm adding starter configurations for `elm-review`. Using the `--template` feature I introduced back in [Try it out](/2.3.0-just-try-it-out), this was actually a pretty easy addition.

So why didn't I do this earlier?

### It's a fine line.

In the `ESLint` community, there is a `recommended` configuration (actually, multiple) where some rules are enabled by
default. And there are multiple very popular configurations that are used by millions, with potentially custom or very
opinionated rules, like [`eslint-config-airbnb`](https://www.npmjs.com/package/eslint-config-airbnb). Airbnb's
configuration is the set of rules that they agreed upon internally at their company. As long as there is consented
buy-in, any configuration is fine in my opinion.

One of the downsides is that people often don't configure their static analysis tool any further than enabling a popular
configuration, even though it's such a powerful and **customizable** tool ("because smarter people
have thought about this deeply"?).

But the biggest problem when people adopt these "community" rules blindly (especially large ones like Airbnb's) is that they create a lot of friction.

Developers will find a linter error that they will disagree with (as they didn't review and choose the rule) and get frustrated. In the best case, it will trigger a
constructive conversation in the pull request but that can delay the PR's merge. In the bad case, the developer will add a
[disable comment](/disable-comments). In the worst case, it will create a hostile environment where people badmouth the
configuration and whoever set it up everytime they see a "stupid linter error".

I have seen this situation several times in the office and online, and avoiding these situations has always been a
conscious goal of mine when making `elm-review`. That's why I put such a high amount of work in reducing false positives,
why `elm-review`'s docs are full of guidelines, why the tool is so configurable,
why there aren't [built-in rules](https://github.com/jfmengels/elm-review/blob/master/documentation/design/no-built-in-rules.md),
but also why there wasn't a recommended configuration.

Before I first released `elm-review`, I was actually quite worried that I was opening Pandora's box of (code style) rules,
like what happened with `ESLint`. For reference, I am the original author of the `eslint-plugin-import`'s rule [to sort imports](https://github.com/import-js/eslint-plugin-import/blob/HEAD/docs/rules/order.md).
I remember people making a lot of requests to support sorting in a slightly different way. Eventually they ended up
forking the rule and publishing it in their own projects. Searching for [`eslint sort import`](https://www.npmjs.com/search?q=eslint%20sort%20import)
returns 40+ `npm` packages at the time of writing. And that is only ONE code style decision.


### The starter configurations

From what I see, `elm-review` configurations tend to be very similar in practice, because the commonly used rules are
very reliable, and there are not that many code style rules out there.
I think and hope that it will stay somewhat like that, and after 2 years, I think it's somewhat safe to create some starter configurations.

The documentation and CLI will gently suggest these configurations to get started, but I do hope that they don't feel
like "You should enable these!", that's not the point (even though in my personal opinion you definitely should!).

I put these starter configurations in the [jfmengels/elm-review-config](https://github.com/jfmengels/elm-review-config)
repo, separate from the tool, and you can use them easily through the examples below.

These are meant to be **starter** configurations. I mostly added those that I think will work for every project, but what
they contain may change depending on my own personal beliefs.

Don't like something? Feel free to remove it. Want to add more rules? Add them.


#### For an Elm application

```bash
elm-review init --template jfmengels/elm-review-config/application
```

#### For an Elm package

```bash
elm-review init --template jfmengels/elm-review-config/package
```

#### For an elm-review package

Note that you already get this when running `elm-review new-package`, which I **highly** recommend because you get even more useful tools for free.

```bash
elm-review init --template jfmengels/node-elm-review/new-package/review-config-templates/2.3.0
```

#### Personal configurations

I will likely at some point include my personally preferred configuration in there, not as a starter
configuration but so that I can personally set up new projects easily.

If you want to do so for your own as well, it's pretty easy: create a repository like [jfmengels/elm-review-config](https://github.com/jfmengels/elm-review-config),
put your configuration there and push it to GitHub. And then you can use it like this:

```bash
elm-review init --template <your-name>/<project-name>/<folder-name>
```

### "Jeroen, I think rule X should be in the starter configuration"

Feel free to suggest rules to add! But I have a few guidelines in my head for what to include and not include.

I think the rules should be useful for almost all projects. I won't add rules that only work if you use library Y.

There are a few rules that are awesome, but require users to know about it.
[NoMissingTypeConstructor](https://package.elm-lang.org/packages/Arkham/elm-review-no-missing-type-constructor/latest/NoMissingTypeConstructor)
for instance is a very nice rule to make sure that some lists contain all variants of a custom type.
But it requires users to write their code in a specific way (having the variable name start with `all` for instance),
which will not happen if they didn't read the rule's documentation (which is likely when they didn't choose the rule themselves),
making the rule useless. [NoForbiddenWords](https://package.elm-lang.org/packages/sparksp/elm-review-forbidden-words/latest/NoForbiddenWords)
is another great example of such a rule.

I have written a few rules that are in that category, and chose to not include them (and it hurt my little heart).

As you may have guessed, I tend to avoid code style rules. I will include them only if I believe it's always for the
better. I do enforce running `elm-format` in `elm-review`, so it's not like I'm opposed to enforcing code style rules,
just that `elm-format` is a very good and almost sufficient default.


### Afterword

I hope you find this useful and that it removes a barrier for you to try `elm-review` or to use it on more of your projects.

I do hope you keep using `elm-review` as it was intended: through mindful decisions.