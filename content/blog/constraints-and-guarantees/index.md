---
title: Constraints and guarantees
slug: constraints-and-guarantees
published: "2024-09-16"
---

I love having guarantees, things that I know are true about the code or system that I'm working with. They make me more productive, less anxious about making a change, and they make others confident enough to send people to space.

I believe that guarantees are gained through constraints, and lost through the addition of features, which is why I like working with constrained systems. Not because I like playing in hard mode - on the contrary - but because it can move some of the hard tasks from hard mode to easy mode by creating powerful guarantees.

In general, features in software languages and tools tend to be considered positively while constraints tend to be considered negatively. I believe this is unfair, so I want to go through why the absence of a feature sometimes makes for the best system.


## We want guarantees

There are many kinds of guarantees. There's the guarantee that:
- a function returns what it's supposed to return
- some piece of code doesn't crash
- a feature works as expected
- software is not affected by known vulnerabilities
- code is written in a way that others would be happy to maintain
- you can safely change code in a specific way

...and many more.

Some are very technical, some are at a human interaction level, and some are even higher. Human rights for instance - such as access to drinkable water - can be made into near-guarantees by government policies with sufficient will and means.

As a software developer, one of the things I want to do all the time is to create guarantees. Whenever I write a feature, I want to create guarantees - that it works as expected and that it is used as intended. Whenever I fix a bug, I want to create guarantees - that the bug can't happen again.

I would argue that it is our job and responsibility as developers to create guarantees regularly.

We want guarantees because they allow us to get faster and to do more things. If I know a piece of code is very well tested through automated tests, then I feel more at ease modifying it because I will get notified if I break something. If I know it's not tested at all, I will tread a lot more carefully.


## Guarantees need constraints

The problem is that guarantees don't come for free. **To get a guarantee, you need constraints**. And without constraints, you have no guarantees.

A constraint means that something is impossible. That can be absolute, meaning something is completely impossible, or it can be a restriction, meaning something is impossible under certain circumstances or impossible with certain methods.

Here's a simple example. Say you have a function `add(a, b)`. What do you know about it? That its name is `add` and that it takes 2 arguments. And that's about it. What does it do? We can't know for sure. It may add numbers, or it may do something entirely different.

Let's say we want the guarantee that it does what we expect it to do, which is to add numbers. A reasonable approach is to add automated tests.

We add a test that checks that `add(0, 0)` equals `0`. That is our new constraint.

`add(1, 1)` might return `5`, or it might crash, but we now have the guarantee that `add(0, 0)` will equal `0` (at least in the context of our test, and only if we ensure the test passes, but let's simplify for now and assume that's always true). 

**We added a constraint and we got a guarantee in return.** A small and situational one, but a guarantee still.

This doesn't prevent the function from being changed or entirely rewritten, but as long as that test remains it will prevent it from returning any other value for this particular input.

In some cases, you might think you do not need any constraints to get a specific guarantee. While that can happen, I think it's more likely that there are other constraints in the system that gives you this guarantee for free.

I've seen this kind of constraint be named "liberating constraints" or "constraints that liberate".


## Composing constraints

The constraint we added for the `add` function above is insufficient, we are still guaranteed very little about it. Thankfully, adding more constraints will yield more guarantees. We can add more unit tests and/or we can use different kinds of constraints until we are guaranteed that the function behaves as expected in the contexts that matter to us. 

We can use varied methods, tools and processes that constrain the system. Unit tests, end-to-end tests, type checkers, static analysis tools, dynamic analysis tools, regression benchmarks, build tools, custom languages, code reviews, release processes, checklists...

You can use all of these, and many, many more. A lot of the tools that you use are there to create guarantees of some sorts, even if that doesn't seem obvious and if it's not advertised that way.

The more constraints you add, the more terrain you cover and the more complete your guarantees become, which will allow you to trust your knowledge of the system more, and ultimately go faster.


## Similar constraints are not equal

Some constraints look the same on the surface, yet yield different guarantees.

Elm's and Java's static type systems are both there to prevent invalid operations on types, however their design leads to very different guarantees. The former requires little to no type annotations and lets people be very confident in making changes, while the latter requires a lot of ceremony yet doesn't prevent the occurrence of `NullPointerException`s.

Some constraints yield more - or more complete - guarantees than others. They can be terribly designed and not get the desired benefits. Or even worse, they create adverse effects, opposite of what was hoped for.

Slight differences in design can bring about very different results, hence some constraints may need to be defined with care.


## Figuring out the guarantees

I think it's interesting and sometimes important to understand the **exact** guarantees you have, the scope thereof, as well as the required conditions, as having incorrect beliefs can lead to errors.

You may not know that your `add` function works as expected 100%, but if you're aware of that, you could add additional safeguards and checks, turning your partial guarantee into a complete one.

For the test `add(0,0)`: we have the guarantee that `add(0,0)` equals `0`, as long as: the test runs and successfully passes before a deployment, and is unmodified before the deployment.

If we add a type annotation on the first argument that states that it has to be a number, then we get the guarantee that it's a number, as long as the type checker runs and successfully passes before deployment and no incorrect escape hatches have been used (incorrect casting, etc.), as well as if the type checker is sound and reliable.

I'm sure one can find even stricter scopes for the things I mentioned.


## Constraints bring guarantees

To get a guarantee, you need a constraint. The corollary is that when you have or create constraints, you also gain guarantees. Whether those guarantees are desirable should be studied on a case by case basis.

For instance, if you go to a river to fish, you know you won't have to look for fish on the river bank because they can't breathe there. That allows you to maintain your focus on finding them in the water.

That is an example of an innate constraint, a physiological one. It doesn't have any *designed* guarantees or benefits, but you can extract some anyway. There are many kinds of these constraints: physical, historical, legacy, political, etc.


## A feature is a lack of constraints

As I said earlier, a constraint is the impossibility to do something. A lot of things are impossible by default, especially in programming languages or software products. If a language is empty, there is nothing they can express and therefore nothing that they can do with it.

What allows users to bypass an impossibility is commonly called a feature. **A feature is therefore the opposite of a constraint**, it is the lack of a constraint.

This can be simple things like being able to declare a variable, being able to mutate variables, supporting some specific operation on a specific type, supporting a specific syntax, or having a button in the application. It is anything that increases the distance from the empty set of possibilities or the number of ways something is expressed.

It might be something that you might find natural to have, but that somehow is absent in some other language or done differently.

Features are necessary, because without them everything is impossible, you need enough features to be able to do the task you're trying to accomplish. But every feature reduces the constraints, and every removed constraint means less guarantees. 

Yet we need some amount of guarantees. We feel pretty happy knowing that an operation like `1 + 2` will never crash. If we don't even know something as basic as that, writing software would be terrible (actually, there are a few languages where this could crash...).

When people talk about adding features, they often talk about trade-offs between feature designs. If you do it this way, you get this set of benefits and drawbacks, and if you do it this way, you get this other set.

But a trade-off that I think is not mentioned - or evaluated - enough is the trade-off of adding the feature in any shape versus not adding it *at all*. Whenever you add a feature, you lose guarantees about the system (and I'm not even getting into the added complexity of a new feature). Whether the feature is worth the trade-off is sometimes hard to foresee.

There have been languages and frameworks that I have tried learning where I could not find in me the strength to finish the tutorial. I would very quickly see a number of features (henceforth also known as "non-constraints") that meant that a number of guarantees that I personally strongly desire - because I think they're necessary for maintainable software - are near-impossible to get. I found the system to not be constrained enough.


## Features require new constraints

A lot of the things developers want are the same, making bug-free software being near the top. If you start looking for it, you will find that the presence of a feature tends to lead people to try to regain some of the guarantees it retracted, through new software, processes, tools or even businesses.

The amount of energy, brainpower and money spent to prevent `null`-related errors is astronomical. There have been many scientific papers on tracking them down, and many businesses try to help you prevent them.

But supporting `null` - and especially as an implicit possibility for every value - is a feature. If you take a look at languages that don't support `null`, you notice that they won't have this crash. They have the guarantee that that won't be a source of errors (for some of them at least), and they don't need additional tools or help for that.

**A feature costs guarantees**, and people will try to get some back.

Another (very basic) example: as soon as a language supports declaring functions, we lose the guarantee that we don't have unused functions. Then people create static analysis tools to detect unused code, [with more or less success](https://jfmengels.net/safe-dead-code-removal/).

A lot of other linter rules report about misuses or potential problems surrounding language or framework features.

When a language supports mutation, you lose the ability to freely run code across threads. People then invent semaphores and mutexes, or they add analysis tools to figure out whether it's safe or unsafe to split execution into threads - among other solutions by trying to detect whether there is mutation or not in the relevant code.

Even the simple act of introducing the `add` function requires the addition of constraints such as tests. If the program is proven to be without bugs or crashes, then an unconstrained new function gets introduced, can you tell whether you still have a flawless program?


## Love your constraints

Constraints tend to be considered negatively. The absence of a feature - or the inability to do something - in a language, framework or tool can drive people crazy.

Now that we all know that guarantees and constraints are two sides of the same coin, this apprehension feels undeserved and unfair.

Plenty of countries mandate vaccination against a number of diseases. If applied sufficiently thoroughly, we can stop worrying about them. Diseases like smallpox were eradicated thanks to that, and it's now just a bad tale.

Starting in 1986, countries all over the world started [banning the use of lead in gasoline](https://ourworldindata.org/leaded-gasoline-phase-out) (restrictions started before that time), which saved a large part of humanity from lead poisoning (or from worse lead poisoning).

These are examples of constraints with huge benefits for humanity.

Once you know of the benefits, you can appreciate the constraints themselves. If I hear about mandated vaccination, I know it's very likely done in order to prevent something much more terrible. And that makes me love the constraints.

I think it's a healthy habit to be curious about constraints. I can't always guess it, but I'm always hopeful that a constraint was set for good reason. If there's a sign on the beach saying "No swimming allowed", I could throw a guess that there are sharks, or that the currents are surprisingly strong, or that there are fragile and endangered species in the water, and I can respect that. (Though it would be great if there was an explanation somewhere...)

This habit of wondering about the benefits of a constraint should be applied to software as well. Language X doesn't support this feature? Maybe it's a technical limitation, maybe it will be added later, or maybe - *just maybe* - it is a design choice that unlocks some really nice benefits.

You may still disagree that the benefit is valuable - or valuable enough to warrant the constraint - but that hopefully can lead to informed discussions and decisions.