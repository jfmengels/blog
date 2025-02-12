---
title: A nice round ball
published: "2023-01-27"
---

Someone recently asked me where I get the motivation to work on [`elm-review`](https://elm-review.com/) and other projects. I'm no motivation expert (far from it), but I can try and explain what seems to work for me and my projects.

## Scratch your own itch

The first important bit for me is to use the projects you're working on. Even though I'm making a tool that hundreds or
thousands use regularly, my concerns start self-centered. For `elm-review`, the initial itch that I wanted to scratch was to not
have to tell colleagues how to write their code or to remember to do certain things. I now have a linter that does that for me.

A common advice when starting in open-source is to contribute to projects you're already using, which I think is good advice
because 1) you will already have some knowledge of the project, and because 2) you'll be able to see the value of your
work as you use the tool afterwards.

I like the fact I made an extensible tool which allows people to write linter rules that scratch their own itch, because
they will in turn sometimes solve issues that I had too.


## A nice round ball

A large part of why I put so much effort into `elm-review` is because of how I subconsciously visualize it.

I kind of view my project like it's **a nice, round, inflated ball**.

This ball is simple, and it's perfect. There isn't anything about it that you can criticize, except mentioning that
there are some things you can't do with this ball.

Sometimes when I or someone else is playing with the ball, we discover that there is a hole in the ball.
Oh no! I'd better fix that! So I find the hole and patch it. What I'm trying to avoid is the ball getting deflated.

There are two things that determine how quickly the ball is getting flat: the number of holes, and their size. The idea
is to not have any holes to start with, to prevent holes from showing up by making the ball hole-resistant, and to fix
them quickly when they ultimately show up.

To make sure the ball is still being played with, some people need to fix the ball. The more we can relay each other,
the likelier it will be that it will stay in a good state.
Also, every so often it needs a bit of novelty (new drawings on the ball, new ball games to try out), otherwise people will get bored with it and find new toys and games.

---

In this metaphor, holes are bugs or anything that can be considered like a bug, such as inconsistencies, misleading or
unclear error messages, etc.

Large holes are very problematic issues, like the tool crashing or reporting wrong things.
And tiny holes might be typos in docs (that'd be a super tiny hole, but a hole nonetheless). 

That's how I somewhat subconsciously see my projects. But if I think about it consciously, I can push the metaphor a bit
further and still make *some* sense 😄

So what is the project inflated with? What leaves the ball when there are holes? I'd say it would have to be trust and usage.

If there are too many issues — or too large ones — and too much time passes, people will lose trust in the tool.
Once people stop trusting the tool, people will prefer taking a different one (would you pick a deflated ball?).

And once there is no more usage, the project is dead.

---

And that's kind of how I view `elm-review`, like a nice round ball. (In practice, I see it more like a nice round balloon,
but I'd say the analogy works slightly better with a ball when I'm trying to explain it.) 

It's a high-quality and nearly bug-free tool that correctly does what it should do. If it's bug-free, the only complaint
you can have is mentioning what it can't do or be used for. Maybe I'll support that feature you have in mind later, but
you can't argue it's doing a bad job for what it currently supports.

When I initially released the tool, I put a lot of extra work to polish the experience and handle the edge cases.
Therefore, when I released it, it was already a nice round ball(oon), without large gaping holes. And I
meant to keep it in that perfect shape ever since.

I keep developing `elm-review` because there are some things that I want — itches that still need scratching — that I
know that `elm-review` can solve, but not in its current state. In the process of making new features or improving parts
of the tool, new bugs and rough edges ultimately appear. If they get released unbeknownst to me, then they are holes that I'll need
to fix before people lose trust in the tool.

I try to be quick with fixes because it is motivating to get back to this perfect shape. It is satisfying to know that
your tool is in a flawless state. If the project has too many holes, then it's discouraging (and somewhat not worth it)
to go fix those holes. If it only has one, then it absolutely feels worth it to go and fix it.

I also sometimes feel like I need to be quick because when there are holes, time deflates the ball. But even
when I don't feel the rush, just knowing that people will feel happy to learn their issue has been fixed within a short
amount of time feels nice.

---

In summary: the higher the quality of the project, the more likely you'll want to keep it that way. For me, it's mostly
about handling all cases, avoiding bugs, nice error messages, etc.

For others, it might be about performance: seeing a performance regression in their project might be a big call out to
action, because they feel some pride in having a fast project the same way that I take pride in `elm-review`'s
correctness and developer experience.

Pride is a double-edged sword though. The more work you put into something, the more guilt you'll get once something goes
terribly wrong, or once you abandon it for various reasons. I've had projects like these that I had to abandon in the past,
and I still feel bad about them to this day (wounds heal, but slowly).

I hope this was a useful insight into my work, and that it may motivate you to make high(er)-quality things too.

If you'd like to help me stay guilt-free and continue working on `elm-review` and others tools for a long time (and one day do it full-time 🤞),
please consider [helping me out financially](https://github.com/sponsors/jfmengels/).