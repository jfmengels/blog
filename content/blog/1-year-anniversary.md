---
title: 1 year of elm-review. What lies ahead?
content/blog/1-year-anniversary.md
published: "2020-09-29"
---

elm-review v1 was released on September 29th 2019. Today therefore marks the first anniversary of its release! 🥳🎉

## Ambitions

I have pretty much summed up what happened for `elm-review` this year in a few blog posts, including one partial recap. If you are interested in knowing what happened before, I recommend reading through these blog posts (listed are in chronological order):

- [Announcing `elm-review`](/announcing-elm-review/)
- [`elm-review` v2](/elm-review-v2/)
- [What has happened since `elm-review` v2?](/what-has-happened-since-elm-review-v2/)
- [2.3.0 - Just try it out](/2.3.0-just-try-it-out)

Instead, let's concentrate on the future and see how I would like to make the tool and its ecosystem evolve. Note that this is not a roadmap and that things are not in any order. They may happen one day but they may as well never happen for lack of resources or because I changed my mind for good reason.

I have recently created [`elm-review-design-discussions`](https://github.com/jfmengels/elm-review-design-discussions), where I will put my thoughts and proposals for everyone to comment on and pitch in. Some of the things I will talk about have been described in a lot more detail over there, and others haven't but will. I find that writing these ideas down is very time-consuming, so if you're interested in a subject, let me know and I'll try to prioritize it.

### Continuing what elm-review already does well

I think that a lot of what `elm-review` does, it does well. There are few notable bugs, the API is fun to use, the error messages are great and the testing experience is awesome.

I think the documentation is quite alright - it's filled with examples at the very least - but I'm sure there is room for improvement. Sections could be terser or better formulated, the general structure could be reorganized, values and priorities could be highlighted more, and more trivial things skipped over.

I am sure the way the errors get reported can be improved in some way too.

These are things that get improved mostly through feedback: People tell about me things that bother them, then I explore how it can be improved. Without feedback, there is less incentive for me to revisit these topics. As you'll see in this post, there is a lot I want to work on (and a lot more things are not even mentioned) and my resources are fairly limited.

### Continuing to grow the rule ecosystem

I want to keep improving the quality of existing rules and growing the list of useful rules. The majority of the rules out there have been written by me, and even though I enjoy writing these rules, I think the tool will do better if others start (enjoying) writing more rules.

I have been doing a lot of work to create ready-to-develop review packages through `elm-review new-package`. I will be continuing that work, and trying to make it easier for people to contribute ideas or work, such as in [`elm-review-rule-ideas`](https://github.com/jfmengels/elm-review-rule-ideas) or through events like [Hacktoberfest](/hacktoberfest-2020) 😉.

### Editor integration

It is important for adoption of a tool like `elm-review` that it is close to the user's normal workflow. Users seem to mostly not go out of their way to run a specific tool before committing and creating a pull request. Thankfully for the quality of the codebase, you can enforce that whatever they forgot to handle will be checked by the CI, but the user's discontent can be vocal.

The best way to integrate into their workflow is by integrating with the editor. At the moment and as far as I can tell, there are two main editors used with Elm: [IntelliJ](https://plugins.jetbrains.com/plugin/10268-elm) and [VSCode](https://marketplace.visualstudio.com/items?itemName=Elmtooling.elm-ls-vscode).

As I mentioned in earlier blog posts, I have started work on integrating `elm-review` in IntelliJ, because that's the IDE I and my team have been using. Editor integration is not something I really want to work on and maintain if I have to be honest, but I know that this is key for adoption and this will therefore be one of my top priorities. I do try to work on the project in a way that brings me joy so that I don't get burned out, so I de-prioritized this task several times already in favor of tasks that seemed more fun to me. I'm sure I'll be glad when I have it working though!

### Integration with the compiler

One thing I learned when reading ["Lessons from Building Static Analysis Tools at Google"](https://cacm.acm.org/magazines/2018/4/226371-lessons-from-building-static-analysis-tools-at-google/fulltext) (my most exciting read this summer, which may be an indication that I'm not an avid reader) is that it can be beneficial to get the review errors along with the compiler output in order to easily integrate into the user's workflow.

While forking the compiler is an idea that can bring some other useful benefits (access to [type inference information](https://github.com/jfmengels/elm-review-design-discussions/issues/3) for instance), it's not the solution I primarily envision.

[My current proposal](https://github.com/jfmengels/elm-review-design-discussions/issues/2) is to have `elm-review` somehow call `elm make`. If `elm make` reports errors we show them, and if it doesn't we show the review errors if there are any, potentially going as far as preventing the output of the generated file if there are review errors.

Apart from resolving the issue of unused code failing the compilation which would be annoying, I do think it's a very interesting solution so that users can keep their current workflow while also being aware of the problems that `elm-review` reports, as it they were an extension of the compiler. I hope that this and the editor integration would make your colleagues less disgruntled 😁

### Performance

Performance is a never-ending concern for tooling. `elm-review` has gotten faster over the releases, but I am still unhappy with the time it takes to run on larger projects. One way I envision improving this is by splitting the review process up into several processes, or in other words: parallelization. This has a lot of potential for gain, but I'm not yet sure it will: It potentially defeats other optimizations we have that rely on everything being single-threaded which would lead to more wasted work. I'll link to the issue when I create one.

I also want to explore incremental linting, or caching the results of the analysis, so that we can skip a lot of computations that was done in a previous `elm-review` run. It seems to be both tricky and promising. I don't yet know whether we should cache the reported errors or if we should cache the internal contexts of each rule. I'll link to the issue when I create one.

Another issue I want to improve is the performance of `--fix-all`, which when you're cleaning up a yet untidied codebase can take a long time. I once ran it for 32 minutes! But it did end removing like 4500 LOC in the end, so not necessarily a bad deal 🤷‍♂️. There is a lot of wasted work when running with this flag and preventing that wasted work can improve the performance in drastic proportions. I'll link to the issue when I create one.

### Incremental adoption of rules

It can be daunting to enable new rules and especially to start using `elm-review` due to the number of errors it would potentially find when you don't have the ability to ignore the errors in a more granular way than per-file or to have the errors be marked as warnings.

I have thought of [one way to make this adoption a lot easier](https://github.com/jfmengels/elm-review-design-discussions/issues/4).

### Make it easy to find rules and to manage the configuration

`elm-review` doesn't provide any rules or default configuration out of the box. While I think this is still a [correct decision at this phase of the project](https://github.com/jfmengels/elm-review/blob/master/documentation/design/no-built-in-rules.md), it sure doesn't help with the adoption as one of the first things a user needs to do is to find a package containing rules somewhere and install it.

While you can search for `elm-review` on the [Elm package registry](https://package.elm-lang.org/), among [other solutions](https://github.com/topics/elm-review) [for finding](https://korban.net/elm/catalog/packages/dev/static-analysis) [review rules](https://klaftertief.github.io/elm-search/?q=Rule), none of these are perfect and well-enough known. Maybe a new command within `elm-review` to search for or to list rules would be more practical. Maybe a dedicated `elm-review` website would be a good idea but [it might also not be](https://xkcd.com/927/).

Even after you have installed a package, it might get a new rule in a newer version, and it would be nice if the user could just update its dependencies and have `elm-review` tell it what [new rules are available](https://github.com/sarbbottam/eslint-find-rules/).

I have heard of people moving away from `elm-review` because they didn't want to manage/maintain a configuration, even though they already had a configuration set up. While I don't understand why they wouldn't just keep the existing configuration and extend it when needed, it shows that it is a pain point for some users.

I have nothing more than vague ideas here, but it's definitely an area I want to explore.

### Usage as an information extraction tool

I find the `elm-review` API quite fun to use, and much more powerful than using `grep` or `regexes`. When a rule analyzes a project, it may collect contextual data that it will use to know whether it should report an error or not.

We could use the same API to collect data to be used for other purposes. For instance if you use CSS files and classes, you could extract the list of CSS classes currently being used in your application, and pass that to your CSS linter which would tell you to remove the unused classes. We could also have a rule that extracts the Markdown documentation of the whole project so that a script can create those files. You could then use that to publish the documentation in a custom way on your product website, or you can use a Markdown linter to report grammatical issues.

For the Markdown linting, we could also build those rules ourselves and they would be more helpful, but I'm sure that this would be far faster to build. And then that might inspire some to write the rules inside `elm-review` 🙂

You could also collect data to find statistics about your project and display them in a dashboard such as module coupling. Or for getting a feel for where to start cleaning an Elm application by detecting code smells: how many times is a primitive type being aliased, how often is `Maybe.withDefault` used, etc.

I don't know whether this would be a different tool that uses the `elm-review` rules or whether we'll extract the rule's visitor logic into a separate package, or none of these. At this point in time, apart from the name of the tool being out of sync with what it does, I think it somehow make sense to re-use the `elm-review` CLI. I'll link to the issue when I create one.

### Rules with false positives

Due to `elm-review` not allowing you to ignore errors or to mark them as warnings, we're bound to have rules with no (or very few) false positive reports. This is great for inciting writing quality rules, and I feel like the results are showing.

That said, as I mentioned before, there is something that is called "code smell". These are patterns that are not necessarily bad, but have a high chance of not being the best solution or signaling something else being wrong.

The team behind ["Lessons from Building Static Analysis Tools at Google"](https://cacm.acm.org/magazines/2018/4/226371-lessons-from-building-static-analysis-tools-at-google/fulltext) had a system where rules that are still in development or are known to produce false positives were being run to create comments during the review process, which would need to be resolved by a human before they could merge the pull request. The options would be either "Please fix" and "Not useful". "Please fix" would tell the creator of the pull request to go fix the reported problem, whereas "Not useful" would dismiss the issue and send a message to the tooling team.

If the ratio of "Not useful" exceeded 10%, the rule would automatically be disabled and someone from the tooling team would have to deem it not useful enough or improve it. Turns out that a lot of the times "Not useful" was clicked was because the reviewer did not understand the reported problem simply because the error message was not good enough!

It's definitely something that I find very interesting and worth looking into. I'll link to the issue when I create one.

### Benchmarking

When writing a rule, you want the rule to be relatively fast. But it can be hard to determine whether a change was beneficial or detrimental to the overall speed. Running the rule over your codebase and timing it is very unprecise because of the overhead tasks that `elm-review` does.

I would like to provide easy ways to benchmark `elm-review` rules, which will probably be something like `elm-benchmark`. I'll link to the issue when I create one.

I also need to document how to write performant rules because it seems like that knowledge is only present in my head 🙄

### More ways to create errors

As I mentioned in ["Safe unsafe operations in Elm"](/safe-unsafe-operations-in-elm), there is no way to create "global" errors that have no code to point to. If you are writing a rule that expects some function to exist somewhere but it could not be found, you can't always point to some location in the project and say "I expected something here". I'll link to the issue when I create one.

Some rules are being given configuration settings. For instance, imagine a rule that reports errors you don't alias some module name by a given name `NoUnconventionalAlias.rule [ ("Some.Module.Alias", "SMA") ]`.

What happens when you give it `NoUnconventionalAlias.rule [ ("", "some alias") ]`? The module name should not be empty and `"some alias"` is clearly not a valid alias. The rule could detect this and report a configuration error. This is also not possible at the moment but I found several use-cases where this makes sense. I'll link to the issue when I create one.

### Make fixes easier

People like fixable rules. While it's not always a good idea to propose an automatic fix, it's great when you can.

The ways that fixes work at the moment are quite primitive, it is basically only replacing parts of the code by strings. It works well, but it makes it hard to do more complex things like renaming a variable or aliasing a module, which is limiting if you want to safely add an import for instance. It is also not yet possible to automatically fix something in multiple files, which again would be nice if you wanted to move or rename a function.

Only vague ideas here at the moment. I'll link to the issue when I create one.

### Refactorings and migrations

As mentioned earlier, the API is really good at extracting data and understanding contexts. I think this makes it a good tool to help with one-time migrations and refactorings, especially when the fixing capabilities improve. I'm still waiting on Aaron VonderHaar's `elm-refactor` release so that I can steal some interesting ideas 😅

### Feedback / telemetry

As I mentioned, feedback is very important and I don't feel like I receive enough. I am therefore wondering about ways to make it easier for people to give feedback (ideally constructive, but positive feedback also helps). Some tools send anonymized data to servers related the tool to be analyzed later.

I have no clue what data could be useful to collect. Anyway, if I ever add this, it will be opt-in for sure.

## Contribute

As you might have noticed, there's a lot of exciting prospects for the tool. I hope some of these got you excited to take part of the journey. Here are several ways you can help

- Help out through code contributions during [Hacktoberfest 2020](/hacktoberfest-2020)!
- Report bugs or give feedback in the #elm-review Slack channel
- Talk to others about the tool, write blog posts about it
- Pitch in in [design discussions](https://github.com/jfmengels/elm-review-design-discussions) (please watch the repo! 🙏)
- [Propose rule ideas](https://github.com/jfmengels/elm-review-rule-ideas)
- [Sponsor my work financially](https://github.com/sponsors/jfmengels)

Thanks for reading!
