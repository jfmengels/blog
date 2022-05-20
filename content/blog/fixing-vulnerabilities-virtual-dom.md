---
title: How Elm prevents XSS attacks and other security vulnerabilities
date: '2022-05-30T12:00:00.000Z'
---

Last week [I wrote about the vulnerabilities](virtual-dom-security-patch) that were addressed in the `1.0.3` security
patch of `elm/virtual-dom`. I mentioned in there that Elm is doing a lot of work to prevent security vulnerabilities,
which I want to explain in this post. There are other aspects to it, but I will be focusing on only the parts about
rendering to a browser, which deserves its own article.


##

Starting from scratch with sane security defaults
no weird dynamic things, mutation, etc.
It's simpler to consider JavaScript a security vulnerability.
Elm code can't be all that obfuscated

## Elm code is only Elm code

Elm is a language that compiles to JavaScript, but contrary to most other languages even those seemingly close to it,
Elm has a limited interoperability with JavaScript. You can't directly call JS functions from Elm. A lot of people say
this is bad for adoption (sure), makes the language inconvenient (agree on some use-cases) and is stupid (now that's going too far!).

Just like any engineering work, language design is about trade-offs. The less you have, the more solid your foundations
will likely be. The more you have, the harder it will be to make everything work together in a secure and harmonious way.

If you include all the features in the world, or allow free interop with JavaScript, the balance will be super hard to
get right, and you will lose on some of the benefits.

Not including language features is a trade-off as well, and discovering which ones they are [can be quite interesting](https://elm-radio.com/episode/whats-working-for-elm)

Not doing interop with JavaScript means not includes all of its safety issues. Making HTTP requests, sending over cookies...
changing behavior of standard functions. And I'm not even talking about all the runtime errors.

When starting from scratch, we can start without those problematic features.

Can you do HTTP requests? Sure. But it's a lot more explicit. Any effectful instructions need to be wrapped in a Task or
Cmd, which makes it resemble [coloring](https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/) quite a bit.
If we want to figure out whether a dependency of ours is making effectful things like sending an HTTP request, we will be
quickly made aware of it because we'll see that we need to use those values in our update functions in a certain way, and
it will have a light banner `-> Cmd msg` (returns `Cmd`) in the type annotation. And a spotlight shining on `import Http`
and `elm/http` in its dependencies. (NOTE: because of types and managed effects).

In JavaScript, you could probably do `var a = require("http");` in a obfuscated way like
`var a = require([104,116,116,112].map(c => String.fromCharCode(c)).join(''))`, or something even freakier, as
demonstrated [in this way of writing any JS with only 6 characters](http://www.jsfuck.com/).

But can't you handle this with static analysis? Maybe. But considering how often people have false positives (or negatives)
in their JS codebase which you ignore using a `// eslint-disable` comment, I wouldn't trust such a tool to be able to
catch whatever someone with sufficient time will come yp with.

Socket.dev wants to do this approach, but part of this will be simply reporting code that looks obfuscated. Which as they
mention themselves, is hindered by the fact that package authors compile and build their source code before packaging it,
which will quite often be obfuscated.


The language is designed to keep Elm code separate from the JavaScript
code, to keep the code pure and to gain [all the benefits of pure code](https://elm-radio.com/episode/whats-working-for-elm).

Since it's designed for web applications, it also allows you to render HTML in a browser, through a custom virtual DOM implementation.

Since Elm 0.19, Elm made the choice to prevent any JavaScript code from being inserted through its HTML rendering.
For instance, it is not possible to inject a `<script>` tag using `elm/html` nor using the underlying building blocks
defined in `elm/virtual-dom`.

If you attempt to write a `<script>` tag, `elm/virtual-dom` will replace it by a paragraph
`p` tag, which will prevent the execution of the JavaScript code.


## Why would Elm do this?

The way I see it, there are two major reasons.

The major reason for doing these checks is for security reasons. Browsers have access to a lot of our personal data,
and popular web applications can target millions of users. If a malicious attacker is somehow able to insert harmful
code in our application, the results can be terrible for everyone (well, except for the happy attacker).



TODO Not attached to JavaScript runtime


## What checks are being made TODO REPLACE


`innerHtml`, `script`, onclick handlers, formaction

### Preventing XSS attacks

Some languages or frontend frameworks allow you to write things like `<div>{inputFromUser}</div>` which can be dangerous.
If `inputFromUser` is `<script>alert("You've been hit by a smooth XSS")</script>`, then this script can be executed on
the user's machine and those of others.

Elm also doesn't inject strings in the DOM (like PHP would, as far as I can tell).

Instead, every DOM node
that the developers request Elm to create have a type.

Conceptually, a `span` tag is created by `VirtualDom.node "span"` (or its simpler alternative `Html.span` which is the exact same thing) and is simply data untilwould look like a record/object such as `{ type: "node", tag: "span", attributes: [...], children: [...] }`.
Only at render time will it be transformed into an actual DOM node through `document.createElement(element.tag)` (+ children/attributes manipulation) then inserted in the DOM through the appropriate function like `parent.append(nodeThatWasJustCreated)`.

When attempting to create a `script` tag, Elm simply checks ahead of time whether `tag` equals `script`, and replaces it with `p` if it is.

Text nodes have their own separate record that looks like `{ type: "text", text: "Some text" }`. For those, Elm uses
`document.createTextNode(node.text)`, which makes sure to only display the text as regular text, before inserting it into the DOM.

This is a very cheap (in the good sense) system to prevent XSS attacks. If you want a text node, you need to use the `VirtualDom.text` function
(or `Html.text`). If you want a node, use `VirtualDom.node` or its shortcuts from `elm/html`). Those are the only ways you have to create nodes.

It doesn't need to escape all the text nodes (on top of what the browser natively does) like other frameworks may do
because in Elm there is an explicit difference between injecting a DOM node and injecting text.


### JavaScript injection through attributes and properties

A `script` tag isn't the only way to inject or execute JavaScript code through HTML, you can also do so using HTML
attributes and properties.

For instance, you can add event handlers such as `<button onclick="alert('There is an attacker at the window')"></button>`
which will execute when the user interacts with the element. Elm prevents this by looking the name of the attribute, and
if it looks like an event handler (starts with `"on"`), then that attribute gets prefixed with `data-`, which will
neutralize the attribute. The same happens with the `formAction` attribute.

You can also do `domNode.innerHTML = "<script>alert('TODO')</script>"`, which will replace the contents of the node to
be arbitrary HTML. Elm allows you to set the value of arbitrary properties of DOM nodes like that, but it checks whether
the property is `innerHTML`, and removes it if it is.


TODO turn /^javascript:/


##

JavaScript has a lot of things that can lead to security issues. Elm has a lot less of those. By not allowing JavaScript
code to be included in your Elm project, Elm doesn't inherit from the same vulnerabilities.

Tools that check for security issues in JavaScript code (Socket, Snyk, ...) have a large list of things to look for:
prototype pollution, global/standard functions overrides, HTTP requests, obfuscated code...

In Elm, most of these things aren't available or are restricted and easy to detect (no dynamic stuff). Now, all that is
needed is to patch whatever security issues are reported, because bugs can happen, and then we can consider Elm to be a
secure language. 


## Escape hatches

CRM

ports, webcomponents is the escape hatch.

Since the escape hatches require ports and/or JavaScript code, which are forbidden to be published in the package registry,
it means that you won't find any usage of them in any of the Elm package. You won't find a UI library where it sneakily
inserts code like `div [ dangerouslySetInnerHTML "<script>alert('You were struck down')</script>" ] []`.

If you want to use the escape hatches, you have to opt into those explicitly into your project. It does make sharing
or reusing some solutions harder, but it makes the entire package ecosystem more trustworthy.

HOW these are prevented
WHY
WORKAROUNDS?
    - Ports & Webcomponents, both can't be included in packages (usage of wc yes, not their declaration).
    - https://github.com/elm/html/issues/172

In security, they say "Assume you've been breached, now how do we figure out how/where?" (TODO get exact quote)

In Elm, we basically do the same thing at certain levels. We trust only what the compiler has been able to prove for us,
and the rest needs to be validated and pattern matched.

Want to access the value of a `Maybe String`? Pattern match on it and handle both the case where it's null and the case where it isn't.
Want to access the value of JSON that comes from a HTTP request or from a JavaScript port? [Decode it!](https://guide.elm-lang.org/effects/json.html)

We could potentially do the same thing with JavaScript. The idea would be to write a JavaScript parser that keeps the
parts, execute it in a sandboxed interpreter, and then return the result of that. That sounds like a lot of work to me,
which is I think why I haven't seen it. TODO Remove this section?




## How to upgrade

To upgrade, it should be enough to change your `elm.json` manually by changing `"elm/virtual-dom": 1.0.2` to `"elm/virtual-dom": 1.0.3`.

Once you've done that, you should not have to worry about XSS attacks in your Elm code and the ones from your Elm packages.

I have been searching inside the package registry for packages that abused or even maliciously used these vulnerable and
while I haven't entirely complete the search, I didn't find any suspicious package so far.

### Afterword

As an Elm developer, I have never felt the need to escape or sanitize user input before rendering it or anything. Part
of it is due to my ignorance on the subject, but since learning Elm I have also felt like it wasn't needed, as I felt
like I could trust Elm do the right things for me. And in practice it's not doing much, it's mostly preventing me from
using things like `dangerouslySetInnerHTML` and straight up using or executing arbitrary user-provided strings.


If you find new ways to inject JavaScript code into Elm code, please [open an issue!](https://github.com/elm/virtual-dom/issues/new),
ideally with an [SSCCE](http://sscce.org/).