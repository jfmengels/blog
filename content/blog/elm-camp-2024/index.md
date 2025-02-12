---
title: Elm Camp 2024
slug: elm-camp-2024
published: "2024-07-12"
---

I had the pleasure of going to [Elm camp 2024](https://elm.camp/24-uk/artifacts) this year, which was located in England.

![](/images/elm-camp-2024/elm-camp-24-attendees.jpg)

While writing this, I am sure I am going to regret not writing this down earlier because I will forget great conversations and tidbits. I'm sorry if you feel like I should have mentioned you or our conversation or session! (And similarly, if you feel like I've misunderstood and mis-written something here, please let me know.)

One reason I didn't get to write this is because I was tired on the way back, and then I got so excited to work on some OSS stuff (of which motivation was lacking in recent months, cf my last blog post) that I wanted to do other stuff. That said, I have already worked on like 5 or 6 different projects and started like 10 blog post drafts since, and I've released nothing, so at least in terms of methodology, some improvements could be made.

## The trip and the camp

Just like last year, I took the train there, and was happy to notice it was a *short* travel by train, at least relative to last year where it was in Denmark (2 x 10-12h, instead of 16+20 hours).

Even though it's definitely not cheaper and not faster, I was at least happy that I could make the travel by train (both in the sense that I can afford it, and in the sense that I'm not polluting as much as with a plane). While on the last train and while waiting for the taxi to the venue - or rather, spending an hour figuring out that a taxi driver was waiting for us but neither party could confirm we were meant to be together - I was already deep in funny conversations with some of the attendees.

The venue was lovely. We had a lot of space to move in and to talk, both inside and outside, and the surroundings were beautiful. There even were lamas!

(Btw, I know that a lot of people complained about the quality of the food, mostly having been spoiled with last year's catering in Denmark. I for one who has simple but poor taste in food found it very nice, much better than last year's fancy food, but I know I'm a minority).

## The sessions - Convince me that elm-review is great for my app

For the sessions, since I'm mostly one who likes programming tools and techniques (hence the contents of Elm Radio), I mostly went to those kinds of sessions.

I had released a new version of `elm-review` a few days prior, which felt good to me, because going there "empty-handed" would have felt disappointing, given all the things I want to build for the community. But the topic being quite niche even for `elm-review`, I didn't feel like suggestion a session about it.

Someone did suggest a topic "Convince me that `elm-review` is great for my app!". I didn't know whether this was trying to be controversial, trolling, or genuine, but I felt summoned and had to go to that session. Not so surprisingly - and just like all the other sessions and conversations - the request was genuine.

The person was on the rather earlier stages of discovering Elm by making a game with it, and had heard a lot that `elm-review` was a great tool but hadn't yet understood the benefits or the errors reported by the tool.

We had a great time with a bunch of other people going through the (my) default configuration, enabling rules one by one, and explaining the rationale for each rule. The result? Yes, we succeeded in convincing them 💪

I don't remember exactly how much they tried running `elm-review` prior to the session, but a few things I remember or got from the session:
- Reading the error messages carefully really helps understanding the error
- it's great to start small, enabling rules one at a time instead of enabling a whole lot of rules

These comfort me and my previous beliefs that I've written or spoken publicly about, but it's always interesting to figure out how to improve it. I should probably have some more practical writings on how to get started with `elm-review` (using `elm-review suppress` for instance).
(Please someone, if you remember more learnings, let me know!)

## elm-syntax-type-inference

During the conference, I definitely felt like Martin Janiczek's groupie, and went to I think all of his sessions.

His first session was about [`elm-syntax-type-inference`](https://github.com/janiczek/elm-syntax-type-inference), a project he started to compute type inference on Elm code. We talked about the practical applications of that, which is mostly for `elm-review` but also for `elm-codegen` (improving the generated types).

For `elm-review`, it can be useful for a bunch of rules, for instance but not limited to:
- `NoUnused.RecordFields`. Not strictly necessary for simple things, but it quickly becomes necessary in order to reduce false negatives. I remember a separate conversation with Simon Lydell who made a [different approach](https://gist.github.com/lydell/bef18961dff0e2b8ae6e175c3a787faa) where I explained in more detail situations where we really can't figure this out without type information.
- Automatic fixes for the `NoMissingTypeAnnotation` rules
- A rule for reporting when the `Model`/`Msg` contains functions, which breaks the Elm time-travel debugger
- A rule for reporting usages of `==` on data that contains functions, which can create runtime errors.

Martin talked about the state of the project, and how people could help out. If you feel this is interesting to you, contributions are still welcome.

## HVM

Martin also talked about [HVM](https://higherorderco.com/), a potential different compilation target for Elm, allowing it to compile to binaries. The promise of this runtime is that everything that "**any** work that can be done in parallel **will** be done in parallel".

Martin talked about [his work](https://github.com/Janiczek/elm-bend) on getting Elm to compile to HVM (or rather to Bend, which is an intermediate compilation step). Bend is a very simple Elm-like pure functional language, making it in theory quite easy to port Elm to Bend.

I have been following the project and Martin's work because - if this does work out well - it would allow to run `elm-review` rules very much in parallel, which I hope would bring much better performance. That said, it would likely require some major changes, because `elm-review`'s visitor pattern is inherently sequential, meaning that in the current shape performance could be very sub-optimal.

Martin says that I'm narrow-minded because I only think about `elm-review` even though this could open Elm to a lot of new opportunities, but hey... yeah maybe he's right.

In conversations, some of the more scientific literature-aware people said that it's unlikely to perform well (outside of some micro-benchmarks), and that it remains to be tested and benchmarked. So far, only small Bend programs have been run, but if we succeed in compiling Elm to Bend, then we suddenly have pretty large existing programs that we could potentially benchmark it with.

Again, if this is of interest to you, reach out to Martin.

## Html.Lazy

A third session from Martin was about `Html.Lazy`, the module in `elm/html` which improves performance.

I initially wanted to go to another session, but in prior conversations on the topic I realized that I knew too much about it and that at work we had done a few innovative things around it, and decided my expertise was needed at this session. Sorry session about "what is missing in the Elm package ecosystem?". Thankfully, it was a really nice conversation.

We talked about how difficult it is to use, how it works and when does laziness not work. We talked at length about what solutions could be found to improve it. Martin talked about having the browser flash the re-rendered view in red to show whenever laziness was defeated. I mentioned that the Gren language was handling the equality through Elm's `==` and not through JS' `===` which feels more natural but probably with worse performance. Also, that at LogScale we collected logs in local environments to track how many times laziness is defeated, and out of that how many times because of new references, and how that helped us detect problems. I also mentioned that I had made a new lazy function at work that allowed for an arbitrary number of arguments.

Lastly, I also mentioned I had an `elm-review` rule for this in a branch somewhere, but it was not yet complete but that I could potentially publish it, depending on whether it currently has false positives or not.

We talked about writing a blog post to explain laziness as it it quite confusing. I only remembered after the event that I had helped Mario Rogic write an explanation on `Html.Lazy`, available on [Elmcraft](https://elmcraft.org/faqs/html-lazy-not-working/).

## Source maps

In his last session (what, only 4?!), Martin talked about Gren's addition of sourcemaps, which we could ~~steal~~ take inspiration from and backport to Elm. This would enable using the browser's step-by-step debugger, but looking at the Elm code rather than the JavaScript one.

We talked about how that would work in the Elm compiler, and decided this could be a standalone project to start with, and potentially backported to the compiler some time in the future.

This is pretty exciting as it would make debugging a lot nicer in Elm, replacing our very `Debug.log`gy approach we have today.

## Virtual DOM

Simon Lydell, also a great yet (too) humble contributor to the community, proposed a session about Elm's virtual DOM where he explained in detail the current problems with Elm's implementation, notably the ones that cause browser extensions to crash the application (but a few others as well).

He explained his explorations into solving those issues, making the virtual DOM more resilient.

Simon is looking for people to help out (especially with testing), so reach out to him if you'd like to help remove some of the last remaining runtime errors available in Elm.

## Becoming an Elm compiler dev

Mario Rogic made a session about working with the compiler, explaining how it works and how we could contribute to forks of the Elm compiler (note: **not** of the language) to create new tools by reusing the great things the compiler already computes and can provide (such as elm-dev, or the sourcemaps mentioned above).

Some people including Mario tried to convince me to rewrite parts of `elm-review` by taking code from the Elm compiler in order to do a lot of the hard work that `elm-review` does such as parsing files, getting the correct module names, getting types for each expression, etc. I have thought of that before, but they did bring a lot of good points. So I can't say I'm convinced yet, but I can't say I am not either.

After the camp, I have already made a pull request to slightly improve Elm's code generation (and I'm interrupting my work on that to write this post) so I am now an Elm compiler dev!

## Improving the world

As much as I love technical stuff, most of the things I had been following or working on recently had already been covered by other people (Martin especially). I did end up proposing one session titled "Improve the world?", as this is something I have been wondering a lot about recently, especially since I'm starting to check more boxes in my life (most recently, buying a house) and feeling like I'm in a place where I should be able to do more for other people and more for the world (although for my sanity, I need to remind myself that I **am** contributing to free open-source software and sharing knowledge).

So I was wondering how we - as generally well-off individuals (software developers being generally well-compensated compared to the rest of the population) - can help the world surrounding us, at a local or global level or any level in between, and wanted to brainstorm or collect ideas from people.

If I would have led the session more, I would have mostly talked about climate change or biodiversity as that as has been on my mind recently, but we only briefly talked upon that. [Katja probably summarized better than I could](https://youtu.be/TzUugc6ukE0?t=1047):

> What came out of that was to start locally: start improving your local community or your local setting and let that kind of branch out into the world. I think that feels very much like an Elm way of doing things. And I think locally can also be the international community that we have. It means just kind of like start with each other that you're connected to deeply.

We talked about starting *very* locally: start by taking care of yourself and loving your family. And from there to get to know your neighbors, try to live and build things with your local community.

One person mentioned spreading awareness of problems, because there are plenty of things you can't solve on your own and if people don't know about them, then it will be difficult to solve.

We talked quite a bit about giving, both time and money. One person mentioned they went to a hospital where they had outdated speakers that still worked with CDs and couldn't get new ones because there was no budget. So this person bought and gifted them a bunch of Bluetooth speakers, which they really appreciated. We can help by donating things that locals need.

We can give to charities (https://www.givewell.org/ was mentioned to help with that). We had a few anti-capitalist mentions, including one about building cooperatives and one about doughnut economics (which I'm not sure I got, I still need to dive in there). Someone mentioned we also be a "good" capitalist, by investing in things we think will benefit the world (investing in renewable energy technology companies for instance). Helping fund open-source was also mentioned (not by me this time)!

And of course we can give our time. For instance if we wish to help in education, then we can volunteer in things like code clubs.

On the topic of nature, we talked about tending to local nature, building bug houses and not underestimating the impact on mythological creatures. Here's [Katja summarizing again](https://youtu.be/TzUugc6ukE0?t=1092):

> Sometimes a side effect of doing something is beneficial to something else that you didn't intend. For example, in the UK there's this tradition of building fairy houses (like little grottos) where you have a pond and a little door for them to come and save space. But actually what that then ends up doing is building a really nice place for animals, birds and insects to come and use the water or hide in the little grotto that you've build the fantastical creature. And the motivation for like, trying to draw in the fantastical creatures is actually helping something in the really world.

---

In somewhat of the same vein, but more conversational and less brainstormy, there was a session about tending to a farm and raising chickens, that we held outside on the campfire ground (by the way, we had camp fires in the evenings, very cozy!).

Since I recently moved to a house with a garden and a small vegetable garden, I thought I would ask about my **very** important concern of the last few months of how the hell do I mow my garden (in a way that does not kill the biodiversity in my garden). I did get to it, but the conversation was unsurprisingly more about having a farm and chickens (and the fact that yes, they lay a lot of eggs), yet included a more surprising story about mice filling literal bathtubs with corn. Overall a nice and relaxing conversation where I learned my garden was likely not large enough to keep chicken.

## Other conversations

As usual with multi-track events, you can't attend everything that you would like. I'm sure there are a few additional sessions where I could have pulled my "We can fix this with `elm-review`!" card but didn't. I've heard multiple times say that one of Elm camp's main themes was education (organically, not by design), and I feel like I missed most of the conversations on the topic. But that's the way it is, you can't be there at every conversation. Thankfully, there are also plenty of conversations outside of the planned sessions.

There were plenty of other conversations that were lovely. Some technical and plenty of non-technical ones, which were very enjoyable.

I remember Leo (@minibill) mentioning we should have `elm-review-simplify` split into controversial and non-controversial rules and giving a few examples. Maybe surprisingly, I am trying to keep them all as little controversial as possible, and sometimes that requires good error messages and explanations, but the line not to cross is sometimes hard to figure out. I feel like overall we did a pretty good job with the rule and have removed the most controversial simplifications.

I had a funny conversation with Mark Skipper. I remember seeing him years ago speaking at an Elm Europe conference. When he got on stage, he said something along the lines of "I have promised myself to talk about climate change at every public opportunity I have" followed by a call to action to fight for climate change. Afterwards he spoke more conventionally about Elm.

I mentioned this to Mark, apologizing that I didn't remember the Elm part of the talk, and he told me "But you remembered the most important part!", surprised I even remembered. We then talked about how he currently fought for climate change, mostly around his [Faces of Rebellion](https://www.facesofrebellion.org/) project.

During lots of conversations, I felt some frustration because people mentioned things that I have looked into in the past - made tools for or wrote blog post drafts - but never finished. For instance, I have a somewhat working rule for `NoUnused.RecordFields`. I have a somewhat working rule for reporting issues with `Html.Lazy`, and there are plenty of improvements to `elm-review` rules (more autofixes, etc.) that I have written down as ideas or outright have branches for, and that I should try to get released.

One thing that brought me a lot of joy is how often people mentioned `elm-review`: how it solved problems X or Y, and how basically it was a great tool and asset for the community. I am usually humble - probably to a fault as my low self-esteem is a source of mental health issues for me - but this felt great to hear and was highly motivating to do more. Thank you to each one of you who said something nice about it ❤️

And there were plenty of more enjoyable conversations all around, I'm not going to list all of them.

## Thanks, and getting involved

Thanks a lot to the attendees for making this lovely event, and bigger thanks to the organizers for making this event a reality once more. I'll definitely try to go again next year as long as I don't have to take a plane.

If some of you want to help organize the event, [please do](https://elm.camp/)! The biggest task every year is to find a venue, so let them know if you know of a nice place in your area, or if you want to help search for one.

Here are more articles related to Elm Camp 2024 if you want to hear more: https://elm.camp/24-uk/artifacts