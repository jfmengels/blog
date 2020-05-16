---
title: Safe unsafe operations in Elm
date: '2020-04-27T00:00:00.000Z'
---

In Elm, we often have modules around a data type which needs a validation when you initially create it.
For instance, the [`elm/regex` package](https://package.elm-lang.org/packages/elm/regex/latest/) defines a [`Regex.fromString`](https://package.elm-lang.org/packages/elm/regex/latest/Regex#fromString) function, which people often use the following way:

```elm
import Regex

lowerCase : Regex.Regex
lowerCase =
    Regex.fromString "[a-z]+"
        |> Maybe.withDefault Regex.never
```

`Regex.fromString` signature is `String -> Maybe Regex`. It takes a string, and if it corresponds to a valid regex, then it returns the regex (wrapped in `Just`), otherwise it returns `Nothing`. When it returns `Nothing`, then we usually call `Maybe.withDefault Regex.never` which will create a regex that never matches anything, but which does give us `Regex` that we can use as if it was valid.

There are in my opinion two problems with the code above.
1. Even if we know for sure that the regex string is valid, we need to handle the case where it isn't.
2. If the regex string is (or over the course of the project, becomes) wrong, we may not notice the problem for a long time.

I don't mind problem 1 too much, especially since we have an easy way of handling the error case.
But problem 2 is the kind of problem for which we would love to have the compiler help us, but it doesn't. I imagine someone could create a new module/package to generate only valid regular expressions, but the API would be much more verbose and far from what people would be used to.
Side-note: Before Elm 0.19, creating a regex with an invalid regex string would cause a runtime error, so the current behavior is in my opinion a vast improvement over the previous one.

In this post, we are going to use the `safe unsafe` pattern: we'll create an "unsafe" function that wraps the "safe" `Regex.fromString` function and that always returns a regex, and using an [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/) rule, we'll make it "safe" by verifying that it is never used with an invalid regex. Also, it will be slightly easier to use than the current way, as it will look like this:

```elm
import Regex
import Helpers.Regex

lowerCase : Regex.Regex
lowerCase =
    Helpers.Regex.fromLiteral "[a-z]+"
```

We could use the same pattern to make it much nicer while as safe to:

```elm
-- Create non empty lists
nonEmptyList : NonemptyList
nonEmptyList = Helpers.NonEmptyList.fromLiteral [1, 2]
-- Create valid email addresses empty lists
email : Email
email = Helpers.Email.fromLiteral "some.address@provider.com"
-- Create numbers in a certain range
num : NumberLessThanFive
num = Helpers.NumberLessThanFive.fromLiteral 3
-- Create game boards with specific sizes for 2D games
board : Board
board = Helpers.Board.fromLiteral [ [1, 2], [3, 4] ]
```

## Create an unsafe function that wraps the safe function

The point of the unsafe function is to wrap the safe function, and simplify the
API to something that will never fail.

Here is what an unsafe function for `Regex.fromString` could look like:

```elm
module Helpers.Regex exposing (fromLiteral)

import Regex exposing (Regex)

fromLiteral : String -> Regex
fromLiteral string =
    Regex.fromString string
        |> Maybe.withDefault Regex.never
```

Notice that `fromLiteral` returns a `Regex`, not a `Maybe Regex`? That's the point here.
You may notice that this is very close to the original example that I have showed before. I call it
unsafe because it can still give you an "invalid" regex.

For other types where we don't have a "default value" that we can use when
things go wrong, the unsafe function would look like this:

```elm
module Helpers.Regex exposing (fromLiteral)

import Regex exposing (Regex)

fromLiteral : String -> Regex
fromLiteral string =
    case Regex.fromString string of
        Just regex ->
            regex

        Nothing ->
            fromLiteral string
```

This function tries to create and return a regex, and if it fails, calls itself again. The recursive call is the unsafe part, because if we enter that case, then we will call the function recursively indefinitely, and the program will in practice halt. Please be careful when using this pattern.

Why did I call the function `fromLiteral`?
It's because we will limit this function to be used only with string "literals" like `fromLiteral "abc"`, and never with something more dynamic or complex like `fromLiteral someString`. The reason for that is that with a literal value, we can easily determine - just by looking at the function call code - whether the function call will fail or not. And that's what the `elm-review` rule we will build next will check!

What if we do call `fromLiteral someString`? Then the `elm-review` rule will warn us about that!

## Detect calls with invalid regexes

Our aim is to detect calls to the unsafe function with invalid regexes, like
```elm
regex = Helpers.Regex.fromLiteral "(abc|"`
```

We are going to start with a simple rule, and update it as we find things we need to handle. Let's start with an empty rule, that does nothing.

```elm
module NoUnsafeRegexFromLiteral exposing (rule)

import Review.Rule as Rule exposing (Rule)

rule : Rule
rule =
    Rule.newModuleRuleSchema "NoUnsafeRegexFromLiteral" ()
        -- Add visitors here
        |> Rule.fromModuleRuleSchema
```

Between the `Rule.newModuleRuleSchema` and `Rule.fromModuleRuleSchema` calls, we are going to add **visitors**.
Visitors are the functions that look at pieces of the source code to report errors, or to extract data into a `context` in order to report errors later on.
This is actually too simple for it to compile: `elm-review`'s package API won't let you compile a rule that does not define visitors, since that would make the rule useless.

We are interested in a detecting calls to the `Helpers.Regex.fromLiteral` function. Function calls are [expressions](https://package.elm-lang.org/packages/stil4m/elm-syntax/7.1.1/Elm-Syntax-Expression#Expression), so we are going to add an expression visitor.


```elm
module NoUnsafeRegexFromLiteral exposing (rule)

import Elm.Syntax.Expression as Expression exposing (Expression)
import Elm.Syntax.Node as Node exposing (Node)
import Regex
import Review.Rule as Rule exposing (Error, Rule)


rule : Rule
rule =
    Rule.newModuleRuleSchema "NoUnsafeRegexFromLiteral" ()
        -- We add a visitor to go through expressions.
        -- We use the "simple" variant because we don't need to collect any data
        |> Rule.withSimpleExpressionVisitor expressionVisitor
        |> Rule.fromModuleRuleSchema


expressionVisitor : Node Expression -> List (Error {})
expressionVisitor node =
    case Node.value node of
        -- We check whether the expression we look at is an "application"
        -- (a function call, kind of) with one argument
        Expression.Application (function :: argument :: []) ->
            case Node.value function of
                -- We check whether the function is `Helpers.Regex.fromLiteral`
                Expression.FunctionOrValue [ "Helpers", "Regex" ] "fromLiteral" ->
                    case Node.value argument of
                        -- We check whether the argument is a string literal
                        Expression.Literal string ->
                            -- We try to call the safe function `Regex.fromString` with the argument value
                            case Regex.fromString string of
                                Just _ ->
                                    []

                                Nothing ->
                                    {- If the safe function returned with the error case,
                                    then we report an error. In all the other cases,
                                    we don't report anything (yet) -}
                                    [ Rule.error invalidRegex (Node.range node)
                                    ]

                        _ ->
                            []

                _ ->
                    []

        _ ->
            []


invalidRegex : { message : String, details : List String }
invalidRegex =
    { message = "Helpers.Regex.fromLiteral needs to be called with a valid regex."
    , details =
        [ "The regex you passed does not evaluate to a valid regex. Please fix it or use `Regex.fromString`."
        ]
    }
```

When you run `elm-review`, the result looks like the following (with color):

```
-- ELM-REVIEW ERROR ----------------------------------------------- src/Main.elm

NoUnsafeRegexFromLiteral: Helpers.Regex.fromLiteral needs to be called with a
valid regex.

83| invalidRegex =
84|     Helpers.Regex.fromLiteral "(abc|"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


The regex you passed does not evaluate to a valid regex. Please fix it or use
`Regex.fromString`.
```

We already have a lot of value here. You could change `[ "Helpers", "Regex" ]` to `[ "Regex" ]` and `fromLiteral` to `fromString` to find when you use `Regex.fromString` with an invalid regex in your project right now (though it will only work when the function is called with `Regex.fromString` exactly).

I am omitting the tests in this post, but you can find the ones for this step [here](https://github.com/jfmengels/elm-review-example/blob/ee514e2839b63b3de6584116f711a9831ee55ca7/review/tests/NoUnsafeRegexFromLiteralTest.elm), next to the [source code](https://github.com/jfmengels/elm-review-example/blob/ee514e2839b63b3de6584116f711a9831ee55ca7/review/src/NoUnsafeRegexFromLiteral.elm).

Next we'll create an error if the argument is something else than a literal string. The rule could be made smarter by trying to find the value for expressions or compute static expressions like string concatenations. We definitely could do that, but the rule will quickly become much more complex. In this case, I think it is not too constraining to force the user to use a simple literal string, and is a fine trade-off for the guarantees we give in return.

```elm
{- Nothing changed from here -}
expressionVisitor : Node Expression -> List (Error {})
expressionVisitor node =
    case Node.value node of
        Expression.Application (function :: argument :: []) ->
            case Node.value function of
                Expression.FunctionOrValue [ "Helpers", "Regex" ] "fromLiteral" ->
                    case Node.value argument of
                        Expression.Literal string ->
                            case Regex.fromString string of
                                Just _ ->
                                    []

                                Nothing ->
                                    [ Rule.error invalidRegex (Node.range node)
                                    ]
{- Nothing changed until here -}
                        _ ->
                          [ Rule.error nonLiteralValue (Node.range node)
                          ]

                _ ->
                    []

        _ ->
            []


nonLiteralValue : { message : String, details : List String }
nonLiteralValue =
    { message = "Helpers.Regex.fromLiteral needs to be called with a static string literal."
    , details =
        [ "This function serves to give you more guarantees about creating regular expressions, but if the argument is dynamic or too complex, I won't be able to tell you."
        , "Either make the argument static or use Regex.fromString."
        ]
    }
```

([full source code](https://github.com/jfmengels/elm-review-example/blob/b8f0c0ec9432a1cf395d6ed5f90dcac7e5ccfe33/review/src/NoUnsafeRegexFromLiteral.elm) and [tests](https://github.com/jfmengels/elm-review-example/blob/b8f0c0ec9432a1cf395d6ed5f90dcac7e5ccfe33/review/tests/NoUnsafeRegexFromLiteralTest.elm))

Great! Now we have something really safe! Well... not yet. There are 3 problems we need to handle:
1. We only report problems when the function is imported and called using the full module name. We won't detect calls to `fromLiteral` or `R.fromLiteral` for instance.
2. People can use the function in complex constructions.
3. We are sensitive to the name of the function, so if it gets renamed or moved, we won't report anything anymore!

Let's handle those one by one.

## Handling all ways to import the function

The problem:
> We only report problems when the function is imported and called using the full module name. We won't detect calls to `fromLiteral` or `R.fromLiteral` for instance.

Our aim is to detect calls to the unsafe function regardless of how it was imported, like:
```elm
import Helpers.Regex as R exposing (fromLiteral)
regex = fromLiteral "(abc|"`
regex = R.fromLiteral "(abc|"`
```

We could report all calls to `fromLiteral`, regardless of the module it comes from, but that could create a lot of false positives. And false positives from this kind of tool annoy the hell out of developers. Don't do it.

Instead, we will manually track the imports, the import aliases, what has been imported from the imports, and what local functions override/shadow what has been imported (because yes, that kind of shadowing is possible). Sounds tedious? Well it is.

Fortunately, a kind soul (yes, that would be me) has created a library to do all that work for us. We'll use the [`Scope`](https://github.com/jfmengels/elm-review-scope/blob/master/src/Scope.elm) module from [`jfmengels/elm-review-scope`](https://github.com/jfmengels/elm-review-scope) by copying the file to our project ([reasons here](https://github.com/jfmengels/elm-review-scope#why-this-is-not-part-of-elm-review)).

We will need to collect data as we traverse the module, so that requires we equip ourselves with a `context`, in which we will store all the useful information, including everything that `Scope` will collect for us.

```elm
import Elm.Syntax.Exposing as Exposing
import Elm.Syntax.Import exposing (Import)
import Scope


rule : Rule
rule =
    -- We're adding an initial context as the second argument
    Rule.newModuleRuleSchema "NoUnsafeRegexFromLiteral" initialContext
        -- We're adding the Scope visitors
        |> Scope.addModuleVisitors
        -- We're adding a new import visitor
        |> Rule.withImportVisitor importVisitor
        -- withSimpleExpressionVisitor -> withExpressionVisitor
        |> Rule.withExpressionVisitor expressionVisitor
        |> Rule.fromModuleRuleSchema

-- The data we're going to collect and use to infer things
type alias Context =
    { scope : Scope.ModuleContext
    , fromLiteralWasExposed : Bool
    }

initialContext : Context
initialContext =
    { scope = Scope.initialModuleContext
    , fromLiteralWasExposed = False
    }

{- The point of this import visitor is just to find out if
`import Helpers.Regex exposing (..)` appears, and store that in
`fromLiteralWasExposed`. Since we are using a module rule, the `Scope
module does not know what is available in `Helpers.Regex`, and therefore
can't know that `exposing (..)` adds `fromLiteral` to the scope.
-}
importVisitor : Node Import -> Context -> ( List nothing, Context )
importVisitor (Node.Node _ { moduleName, exposingList }) context =
    if Node.value moduleName == [ "Helpers", "Regex" ] then
        case Maybe.map Node.value exposingList of
            Just (Exposing.All _) ->
                ( [], { context | fromLiteralWasExposed = True } )

            _ ->
                ( [], context )

    else
        ( [], context )

{- To access the context, we had to make the expression visitor non-simple.
A non-simple expression visitor takes an additional `Direction`, which
tells us whether we entering or exiting the expression, i.e. have we
visited the children already or not.

It also takes the context we are interested in, and it needs to return an
updated context.
-}
expressionVisitor : Node Expression -> Rule.Direction -> Context -> ( List (Error {}), Context )
expressionVisitor node direction context =
    case ( direction, Node.value node ) of
        ( Rule.OnEnter, Expression.Application (function :: argument :: []) ) ->
            case Node.value function of
                Expression.FunctionOrValue moduleName "fromLiteral" ->
                    -- Check if the fromLiteral we found comes from Helpers.Regex
                    if (Scope.moduleNameForValue context.scope "fromLiteral" moduleName == [ "Helpers", "Regex" ])
                        {- Handling Scope's knowledge shortcoming if `exposing (..)` was used
                        Note that ideally, we should also look at whether a `fromLiteral`
                        was declared in the module. But this article is already quite long
                        and we'll solve this problem another way a bit further. -}
                        || (List.isEmpty moduleName && context.fromLiteralWasExposed)
                    then
                        case Node.value argument of
                            {- Omitted, you've seen this part before -}
```

([full source code](https://github.com/jfmengels/elm-review-example/blob/d42cefa8383f81e3199514629cb221c9a9e3f01b/review/src/NoUnsafeRegexFromLiteral.elm) and [tests](https://github.com/jfmengels/elm-review-example/blob/d42cefa8383f81e3199514629cb221c9a9e3f01b/review/tests/NoUnsafeRegexFromLiteralTest.elm))

Great, now we handle all the ways the user can import the unsafe function! On to the next problem!

## Forbidding doing complex things with the unsafe function

The problem:
> People can use the function in complex constructions.

It's hard to handle all the ways the function can be used. Our aim is to detect and report the ones that are too complex and could potentially be used in unsafe ways, like:

```elm
reallyUnsafe = Helpers.Regex.fromLiteral
regex = Helpers.Regex.fromLiteral ("(ab" ++ "c|")
regex = "(abc|" |> Helpers.Regex.fromLiteral
```

We can make our rule smarter to handle most of these patterns, but that would make the rule a lot more complex. I think that tooling/libraries will help with this over time, but we aren't there yet. In this case, I think it is fine to simply report an error anytime we see the function used outside of a function call.

```elm
type alias Context =
    { -- ...previous context fields
      -- allowedFunctionOrValues will register the locations in the code where
      -- the target function was correctly used. We don't want to report those.
    , allowedFunctionOrValues : List Range
    }


initialContext : Context
initialContext =
    { -- ...previous context fields
    , allowedFunctionOrValues = []
    }


-- Moved the targeting logic into a separate function
isTargetFunction : Context -> ModuleName -> String -> Bool
isTargetFunction context moduleName functionName =
    if functionName /= targetFunctionName then
        False

    else
        (Scope.moduleNameForValue context.scope targetFunctionName moduleName == targetModuleName)
            || (List.isEmpty moduleName && context.fromLiteralWasExposed)

targetModuleName : List String
targetModuleName =
    [ "Helpers", "Regex" ]


targetFunctionName : String
targetFunctionName =
    "fromLiteral"


expressionVisitor : Node Expression -> Rule.Direction -> Context -> ( List (Error {}), Context )
expressionVisitor node direction context =
    case ( direction, Node.value node ) of
        ( Rule.OnEnter, Expression.Application (function :: argument :: []) ) ->
            case Node.value function of
                Expression.FunctionOrValue moduleName functionName ->
                    if isTargetFunction context moduleName functionName then
                        let
                            errors : List (Error {})
                            errors = -- Same logic for creating errors as before
                        in
                        ( errors
                        -- Register this function as "okay" to see
                        -- in the `FunctionOrValue` case below
                        , { context | allowedFunctionOrValues = Node.range function :: context.allowedFunctionOrValues }
                        )

                    else
                        ( [], context )

                _ ->
                    ( [], context )

        -- Check if the expression is the target function outside of a call
        ( Rule.OnEnter, Expression.FunctionOrValue moduleName functionName ) ->
            if
                isTargetFunction context moduleName functionName
                    -- If we've seen it in a function call, ignore it
                    && not (List.member (Node.range node) context.allowedFunctionOrValues)
            then
                -- Otherwise, report it
                ( [ Rule.error notUsedAsFunction (Node.range node) ]
                , context
                )

            else
                ( [], context )

        _ ->
            ( [], context )

notUsedAsFunction : { message : String, details : List String }
notUsedAsFunction =
    { message = "Helpers.Regex.fromLiteral must be called directly."
    , details =
        [ "This function aims to give you more guarantees about creating regular expressions, but I can't determine how it is used if you do something else than calling it directly."
        ]
    }
```

([full source code](https://github.com/jfmengels/elm-review-example/blob/3ff48c1312ddad492b6b4cd622a1c960af8090d2/review/src/NoUnsafeRegexFromLiteral.elm) and [tests](https://github.com/jfmengels/elm-review-example/blob/3ff48c1312ddad492b6b4cd622a1c960af8090d2/review/tests/NoUnsafeRegexFromLiteralTest.elm))

On to the last problem!

## Making sure the target function exists

The problem:
> We are sensitive to the name of the function, so if it gets renamed or moved, we won't report anything anymore!

`elm-review` is not able to compare your project with its previous versions, so we can't determine if a function has recently been renamed. What we can do instead, is to report a problem when we can't find `Helpers.Regex.fromLiteral` anywhere in the project.

That is something that we can only determine after visiting all the project's modules. "Module" rules, like the one we built until now, do not have that capability since they forget everything about a module when they start analyzing a different one. In turn, their API is simpler and can benefit from some performance optimizations.

Therefore we will have to turn this into a "project" rule which can remember what it found in other modules. Then we will track if the function was found, and at the end of the project's analysis, if we haven't found it yet, we will report an error.

```elm
rule : Rule
rule =
  -- Turning the rule into a project rule
    Rule.newProjectRuleSchema "NoUnsafeRegexFromLiteral" initialProjectContext
        |> Scope.addProjectVisitors
        -- We add an elm.json visitor to have a file to create an error from
        |> Rule.withElmJsonProjectVisitor elmJsonVisitor
        |> Rule.withModuleVisitor moduleVisitor
        |> Rule.withModuleContext
            { fromProjectToModule = fromProjectToModule
            , fromModuleToProject = fromModuleToProject
            , foldProjectContexts = foldProjectContexts
            }
        |> Rule.withFinalProjectEvaluation finalProjectEvaluation
        |> Rule.fromProjectRuleSchema

-- The "module visitor" tells how we will traverse modules.
-- It is very close to our previous module rule.
moduleVisitor : Rule.ModuleRuleSchema {} ModuleContext -> Rule.ModuleRuleSchema { hasAtLeastOneVisitor : () } ModuleContext
moduleVisitor schema =
    schema
        -- We add a declaration list visitor that will check
        -- whether a `fromLiteral` function was defined.
        |> Rule.withDeclarationListVisitor declarationListVisitor
        |> Rule.withExpressionVisitor expressionVisitor

-- We now have a context for things related to the whole project
type alias ProjectContext =
    { scope : Scope.ProjectContext
    , elmJsonKey : Maybe Rule.ElmJsonKey
    , foundTargetFunction : Bool
    }

-- and one for things related to the current module we are going through
type alias ModuleContext =
    { scope : Scope.ModuleContext
    , allowedFunctionOrValues : List Range
    , foundTargetFunction : Bool
    }

initialProjectContext : ProjectContext
initialProjectContext =
    { scope = Scope.initialProjectContext
    , elmJsonKey = Nothing
    , foundTargetFunction = False
    }

-- Tells how to initialize a module context from a project context
fromProjectToModule : Rule.ModuleKey -> Node ModuleName -> ProjectContext -> ModuleContext
fromProjectToModule _ _ projectContext =
    { scope = Scope.fromProjectToModule projectContext.scope
    , allowedFunctionOrValues = []
    , foundTargetFunction = False
    }

-- Tells how to compile a project context from a module context
fromModuleToProject : Rule.ModuleKey -> Node ModuleName -> ModuleContext -> ProjectContext
fromModuleToProject _ moduleNameNode moduleContext =
    { scope = Scope.fromModuleToProject moduleNameNode moduleContext.scope
    , elmJsonKey = Nothing
    , foundTargetFunction = moduleContext.foundTargetFunction && (Node.value moduleNameNode == targetModuleName)
    }

{- Tells how to fold/merge/combine project contexts together. The
finalProjectEvaluation function will get the result of folding all
the project contexts, each one being the result of visiting a module. -}
foldProjectContexts : ProjectContext -> ProjectContext -> ProjectContext
foldProjectContexts newContext previousContext =
    { scope = Scope.foldProjectContexts newContext.scope previousContext.scope
    , elmJsonKey = previousContext.elmJsonKey
    , foundTargetFunction = previousContext.foundTargetFunction || newContext.foundTargetFunction
    }

-- Grabs the `elmJsonKey` needed to create an error for the `elm.json` file
elmJsonVisitor : Maybe { a | elmJsonKey : Rule.ElmJsonKey } -> ProjectContext -> ( List nothing, ProjectContext )
elmJsonVisitor elmJson projectContext =
    ( [], { projectContext | elmJsonKey = Maybe.map .elmJsonKey elmJson } )

{- Go through all declarations, and see if we found the target function.
The check for the module name is done in `fromModuleToProject`, where we have
easy access to the module name. -}
declarationListVisitor : List (Node Declaration) -> ModuleContext -> ( List nothing, ModuleContext )
declarationListVisitor nodes moduleContext =
    let
        foundTargetFunction : Bool
        foundTargetFunction =
            List.any
                (\node ->
                    case Node.value node of
                        Declaration.FunctionDeclaration function ->
                            targetFunctionName
                                == (function.declaration
                                        |> Node.value
                                        |> .name
                                        |> Node.value
                                   )

                        _ ->
                            False
                )
                nodes
    in
    ( [], { moduleContext | foundTargetFunction = foundTargetFunction } )


-- Checks if we found the target function
finalProjectEvaluation : ProjectContext -> List (Error scope)
finalProjectEvaluation projectContext =
    if projectContext.foundTargetFunction then
        []

    else
        -- If we didn't, report an error in the elm.json file. In future versions of
        -- elm-review, you'll probably have a way to create errors not associated to a file.
        case projectContext.elmJsonKey of
            Just elmJsonKey ->
                [ Rule.errorForElmJson
                    elmJsonKey
                    (\_ ->
                        { message = "Could not find Helpers.Regex.fromLiteral."
                        , details =
                            [ "I want to provide guarantees on the use of this function, but I can't find it. It is likely that it was renamed, which prevents me from giving you these guarantees."
                            , "You should rename it back or update this rule to the new name. If you do not use the function anymore, remove the rule."
                            ]
                        -- Dummy location. Not recommended though :(
                        , range =
                            { start = { row = 1, column = 1 }
                            , end = { row = 1, column = 2 }
                            }
                        }
                    )
                ]

            Nothing ->
                []

{- In project rules, `Scope` has knowledge of what is exported using imports
with (..), so we don't need to remember the imports ourselves anymore.
We also removed the import visitor by the way. -}
isTargetFunction : ModuleContext -> ModuleName -> String -> Bool
isTargetFunction moduleContext moduleName functionName =
    (functionName == targetFunctionName)
        && (Scope.moduleNameForValue moduleContext.scope targetFunctionName moduleName == targetModuleName)
```

([full source code](https://github.com/jfmengels/elm-review-example/blob/78eabbbce4356802d536ae304e762ffa56881ea0/review/src/NoUnsafeRegexFromLiteral.elm) and [tests](https://github.com/jfmengels/elm-review-example/blob/78eabbbce4356802d536ae304e762ffa56881ea0/review/tests/NoUnsafeRegexFromLiteralTest.elm). The tests have changed a bit, since we now need to have at least 2 files in most tests.)

## Summary of the work

We have:
- wrapped a safe function into an unsafe function
- made a rule that
  - checks whether the regex passed to the unsafe function is valid
  - checks whether the argument to the function is a literal string
  - checks whether the function is used in non-handled ways
  - checks whether the unsafe function is present in the project

I think that with all this, we have something really solid that makes sure we don't misuse the function.
We don't want to lose the guarantees that Elm gives us and introduce runtime errors, so I recommend that
if you can't make this check really solid, don't do any of this at all. Otherwise, it's
like if the compiler only checked some of the things for you, and you could still have runtime errors.

Obviously, you need test your rule rigorously. You are writing what is akin to your own "compiler check", but the Elm compiler won't do the job for you here. And `elm-review` provides a [well-built module to help you test your rules](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Test), along with tips and guidelines.

When it's well done though, the `safe unsafe` pattern has the benefit of giving you something similar to automated "unit tests" every time the function is used. No more "well this should always pass" without actually testing it. And no more handling the error case when you know it won't happen, where you usually return dumb stuff anyway.

I strongly recommend against exposing an unsafe function in a package because you think users will use `elm-review` with such a rule. Even if you provide the rule in or next to your package. Instead, prefer letting them define the unsafe function themselves and make it accessible somewhere.

## What did we learn?

I think we learned quite a few things together:
- Writing an `elm-review` rule can be quite easy, for simple cases.
- covering all cases can be much harder: When you do static analysis, you need to think about and handle a lot of cases you wish you wouldn't have to. But it's important, otherwise you may allow things you wished to forbid.
- And especially, using `elm-review` we can create **guarantees** the compiler doesn't give us, and that will sometimes make our code simpler too!

Thank you for reading all the way here, and go build awesome rules!
