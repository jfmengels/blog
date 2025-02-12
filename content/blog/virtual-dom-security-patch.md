---
title: Fixing vulnerabilities in Elm's virtual DOM
slug: virtual-dom-security-patch
published: "2022-05-23"
---

`elm/virtual-dom` version [`1.0.3`](https://package.elm-lang.org/packages/elm/virtual-dom/1.0.3) was released a few days
ago, and it includes a few security patches that help prevent JavaScript code injection through `<script>` tags or HTML
attributes/properties.

`elm/virtual-dom` is the package that gives all the primitives that `elm/html`, `mdgriffith/elm-ui`, `rtfeldman/elm-css`
and others use to create anything visual. So if you're making a web application with Elm, you are using this package.


## How to upgrade

First, let me give you guidelines on how to upgrade.

For Elm applications: You can manually change the version for `elm/virtual-dom` in your `elm.json` to `1.0.3`. You can
find it either under `dependencies`, potentially in the `direct` object but more likely in the `indirect` dependencies.

```diff
{
    "type": "application",
    "source-directories": [
        "src"
    ],
    "elm-version": "0.19.1",
    "dependencies": {
        "direct": {
            "elm/browser": "1.0.2",
            "elm/core": "1.0.5",
            "elm/html": "1.0.0"
        },
        "indirect": {
            "elm/json": "1.1.3",
            "elm/time": "1.0.0",
            "elm/url": "1.0.0",
-            "elm/virtual-dom": "1.0.2"
+            "elm/virtual-dom": "1.0.3"
        }
    },
    "test-dependencies": {
        "direct": {},
        "indirect": {}
    }
}
```

Packages can also depend on `elm/virtual-dom`. As a package author, you can change your
dependency's requirement to `"elm/virtual-dom": "1.0.3 <= v < 2.0.0"` to force your users to use the more secure
versions of `elm/virtual-dom`. But since application developers will need to update their dependencies anyway to get
your increased requirements, I wouldn't recommend going out of your way to publish a new version.


## What were the problems?

I will not go into the details of why or how Elm prevents injecting JavaScript code, as I'll be publishing a more
extensive article on that soon. But in summary, one of the things that we want to avoid is having (illustrative,
not actually vulnerable) code like the following included in our Elm projects.

```elm
view : Model -> Html Msg
view model =
    div []
        [ NormalLooking.code
        , script
            []
            [ text """
                var cookie = document.cookie;
                var request = new XMLHttpRequest();
                // ...code sending personal information with a HTTP request...
              """
            ]
        , Also.NormalLooking.code
        ]
```

If you were to use a package from the Elm package registry, and you used one of its functions that looked like the one
above, then the users of your web application would be running the contents of the script that could have malicious
effects, such as sending their personal information to some servers, or whatever else you can do using JavaScript code in a browser.

Elm actively fights against script injection in order to prevent this kind of exploit, and to keep the language pure (and
therefore reliable). Unfortunately, all prior versions of the package included several flaws in the prevention methods, which
I'll explain henceforth.


## Unchecked VirtualDom.nodeNS

```elm
import VirtualDom

main =
    VirtualDom.nodeNS "http://www.w3.org/2000/svg"
        "script"
        []
        [ VirtualDom.text "alert('Hi')" ]
```

`VirtualDom.nodeNS` is one of the functions to create an arbitrary HTML tag. It takes 4 arguments, the namespace
(useful for SVG among others), the tag name (`div`, `span`, `script`, ...), the list of attributes and the list of children.

Like the other tag-creating functions, it checks whether the tag name is "script", and if it is, changes the tag name to
`p` (paragraph), preventing the contents of the script from being executed.

But a bug in the function caused the check to not work at all, meaning that this script would be injected then executed.
The problem was originally reported in [this issue](https://github.com/elm/virtual-dom/issues/168).


## Browsers don't mind ScRiPt tags

```elm
import VirtualDom

main =
    VirtualDom.node "scripT"
        []
        [ VirtualDom.text "alert('Hi')" ]
```

As mentioned before, when creating a tag, Elm (or rather the `virtual-dom` implementation) verifies that the tag name is
not a script through a `tag == 'script'` check. But browsers don't care about the casing of the tag name, meaning that
if you try to create a `<ScRiPt>` tag, it will happily do so and execute it. This bypassed Elm's check, again making it
possible to inject JavaScript into your Elm code.

This affected all the tag-creating functions (`VirtualDom.node`, `VirtualDom.nodeNS`, `VirtualDom.keyedNode` and `VirtualDom.keyedNodeNS`)
and the functions that used them without directly specifying a tag name, such as `Html.node`.


## Tabs in JavaScript URI

```elm
import Html
import VirtualDom

main =
    Html.a
        [ VirtualDom.attribute "href" "java	scriPt: alert('Hi')" ]
        [ VirtualDom.text "Click me" ]
```

Script tags are not the only way to inject JavaScript code, but it's the easiest one as it doesn't require any
interaction from the user to be executed. But you can also trigger JavaScript code through things like onclick handlers
(`<button onclick="myFunction()">Click me</button>`). A somewhat odd method is to have a link with a `href` property whose value is a JavaScript URI:

```html
<a href="javascript:alert('Hi')">XSS</a>
```

When clicking the link, the JavaScript code in the `href` attribute will be executed.

Elm checks and disables event handlers and anything whose value looks like a JavaScript URI such as above. The problem is
once again that browsers are quite lenient with the `javascript:` part. Yes, it accepts uppercase characters, but Elm did
properly check for that. In this case, the problem was that it was possible to have tabs inside the URI. Meaning that to
a browser, `Java\t\tscr\tiPt:alert('Hi')` is an acceptable JavaScript URI. Note that the browser ignores tabs but not spaces.

This was an XSS attack vector. If in your Elm code, you allow user-provided content to be used as the value of a `href`
attribute and then shown to other users, the script could get executed on those users' computer.

This affected `VirtualDom.attribute` and `VirtualDom.property` and all the functions that used them such as
`Html.Attributes.attribute` and `Html.Attributes.property`.


## Unchecked property values in development mode

```elm
import Html
import Json.Encode
import VirtualDom

main =
    Html.a
        [ VirtualDom.property "href" (Json.Encode.string "javascript: alert('Hi')") ]
        [ VirtualDom.text "Click me" ]
```

As mentioned before, Elm checks the values of properties and attributes. The value of a
[property in Elm](https://package.elm-lang.org/packages/elm/virtual-dom/latest/VirtualDom#property) is a `Json.Encode.Value`,
which in non-production mode is a value with a tiny wrapper around it.

There was a problem where the check for the value of a property was being run on the wrapper rather than the wrapped
value, preventing the safety measures from kicking in.

This affected `VirtualDom.property` and all the functions that used it such as `Html.Attributes.property`. This only
in occurred in development mode though, meaning that it should only affect developers and not the users of their products.


### Practical impact of these vulnerabilities

Except the one related to JavaScript URIs, these are not issues that malicious **users** can likely use to inject malicious
code into your project and send it to other users, because of how static and declarative Elm code is.

The main avenue for an attacker to inject malicious JavaScript code would be through a supply chain attack: publish an
Elm package that contains the kind of code I showed above, and having developers install the package and use the affected
functions that return `Html`.

I have been looking at the contents of the packages in the Elm package registry, and while I have not (yet) completed
looking at all of them, so far I have not found any usage of code that uses the above workarounds.

Elm is a small community that doesn't make excessive use of dependencies and especially indirect dependencies, and the
core building blocks make it so hard to inject JavaScript code. I am convinced that these are all reasons that detract
attackers from considering Elm as an attack vector. In that regard, `npm` is a much more attractive target.

Despite the low probability of these vulnerabilities becoming real attack vectors in your projects, I still recommend
that you upgrade your version of `elm/virtual-dom` as explained above.

### Afterword

It was gratifying to report and help fix these issues, knowing that Elm is now even more secure than before.

It was also very interesting to dive into the security aspects of Elm, so much so that I'll soon write about all that
Elm does to make your code secure.

If you find new ways to inject JavaScript code into Elm code, please [open an issue](https://github.com/elm/virtual-dom/issues/new),
ideally with an [SSCCE](http://sscce.org/).