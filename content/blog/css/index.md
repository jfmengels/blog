---
title: Detecting unused CSS
date: '2020-12-22T14:00:00.000Z'
---

Attacking on both sides:

- Reporting things that we know are bad using elm-review
- Limiting what we can't know using the type system and/or elm-review

---

Example: Detecting unused CSS classes

At Humio, we are gradually migrating from using plain CSS defined in `.css` files, to Tailwind. We are using plain `elm/html`, so we are going from code like this

```elm
import Html exposing (div, text)
import Html.Attributes as Attr

view model =
  div [ Attr.class "user-profile" ]
    [ text model.userName ]
```

to code like this.

```elm
import Html exposing (div, text)
import Html.Attributes as Attr

view model =
  div [ Attr.class "p-4 border-red-500" ]
    [ text model.userName ]
```

During that transition, it can be a bit bothersome to find out all the classes (like `user-profile`) whose usage have been removed and which could be deleted, thereby reducing the amount of bytes sent over the wire. [`elm-review` shines at removing Elm code](https://jfmengels.net/safe-dead-code-removal/), but it can't do much for external resources.

Or could it?

## Detecting unused CSS classes

The first step to this endeavour was to get the list of CSS classes that we have defined, and make them available to `elm-review`. So if we have a file like

```css
.user-profile {
  ...;
}

.user-picture {
  ...;
}

.user-picture > span {
  ...;
}
```

Then the list of classes will be `[ "user-profile", "user-picture" ]`. We don't care about duplicates nor about the non-class selectors.

I wrote a small script (`extract-css.js`) that (TODO Link)

- finds all the CSS files
- Extracts the class names as shown above
- Generates an Elm file from those classes (TODO Link)

The result looks something like

```elm
module CssClasses exposing (cssClasses)


cssClasses : Set String
cssClasses =
    Set.fromList
        [ "user-profile"
        , "user-picture"
        , -- ...
        ]
```

I save this to a file in my review folder, e.g. `review/src-gen/CssClasses.elm`. To avoid annoying conflicts, I save it to a folder that I will Git ignore. So `review/src-gen/` needs to be added to `.gitignore`, `src-gen/` needs to be added to the `review/elm.json`'s `source-directories` property, and then in my test script,
I run this extracting class before

```json
-- package.json
{
  "scripts": {
    "test": "elm make && npm run review && ...other things",
    "review": "node extract-css.js && elm-review"
  }
}
```

This additional step seems to be really fast for us, so it's almost not perceivable in terms of additional time.

Then we go a write a rule that finds all calls to `Html.Attributes.class` and `Html.Attributes.classList` and collects the used class names.

```elm
module NoUnusedCssClasses exposing (rule)

import CssClasses
import Review.Rule as Rule exposing (Rule)
import Set exposing (Set)

rule =
  Rule.newProjectRuleSchema "NoUnusedCssClasses" { usedCssClasses = Set.empty }
    |> Rule.withModuleVisitor moduleVisitor
    |> Rule.withFinalProjectEvaluation finalEvaluation
    |> Rule.fromProjectRuleSchema

type alias Context =
  { usedCssClasses : Set String
  }

moduleVisitor schema =
  schema
    |> Rule.withExpressionEnterVisitor expressionVisitor

expressionVisitor : Node Expression -> Context -> ( List nothing, Context )
expressionVisitor node context =
  case Node.value of
    Expression.Application [ (Node _ (Expression.FunctionOrValue [ "Html", "Attributes" ] "class")), Node _ (Expression.Literal cssClasses) ] ->
      let
        foundCssClasses : Set String
        foundCssClasses =
          Set.fromList (String.split " " cssClasses)
      in
      ( [], { context | usedCssClasses = Set.union foundCssClasses context.usedCssClasses } )

    _ ->
      ( [], context )

finalEvaluation : Context -> List (Rule.Error scope)
finalEvaluation context =
  let
    unusedClasses : List String
    unusedClasses =
      Set.diff CssClasses.cssClasses context.usedCssClasses
        |> Set.toList
  in
  if List.isEmpty unusedClasses then
    []
  else
    [ Rule.error
        { message = "There are unused CSS classes!"
        , details =
           [ "Here are the CSS classes you should either use or remove:"
           , " - " ++ (String.join "\n - " unusedClasses)
           ]
        }
        someLocation -- Omitting details location for now
    ]
```

---

Next steps:

- Better error messages, indicating in which CSS file the classes should be removed from and at what position.
- Creating a wrapper tool around `elm-review` that passes the entirety of the CSS files to `elm-review`, finds the unused CSS classes, strips them from the files and saves those updates files to disk.
- Creating smarter tools around your usage of CSS in Elm, like applying several classes with conflicting properties (setting the color in each class for instance, whose order would be determined almost randomly / in a brittle way).

https://github.com/jfmengels/elm-review-design-discussions/issues/7

---

TODO Make a venn diagram with two circles: (should it be a venn diagram?)

- Left circle: What is valid
- Right circle: What is invalid
- Cross-section: What we know is correct
- Left circle: ...
