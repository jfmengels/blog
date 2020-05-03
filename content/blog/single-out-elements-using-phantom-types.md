---
title: Single out elements using phantom types
date: '2020-05-04T00:00:00.000Z'
---
Today, I have an Elm API design puzzle for you, in which you will learn how to single out elements specific elements of a type.

## The puzzle

Imagine you try to design car factories. You have factories that can build any kind of cars (electric, hydrogen and diesel), and factories that can build only environment-friendly ("green") cars (electric and hydrogen. Though I don't think hydrogen cars are environment-friendly at the moment).

Let's say you want the user to be able to create their customized car factory, for which you provide an API, specifically the `createCarFactory` and `createGreenCarFactory` functions, that reflect the above specifications.

Both functions take a user-provided function to build the cars. For `createCarFactory`, that function can return a `List` of cars of any kind (potentially different kind of cars mixed together). For `createGreenCarFactory`, that function can return a list of only green cars (but potentially also mixed together).

The problem: as the module author, I want the garantee that users won't be able to provide functions that create non-green cars in the `createGreenCarFactory` function, while still being able to create any kind of car with the `createCarFactory` function.

Also, I want to use the type system for this, so that the compiler is the one to complain if these guarantees are not respected by the user of the module.

For simplicity's sake, imagine that cars contain no data.

The following is an example of what the API could look like, but without the garantees I mentioned. You are allowed to tweak and change it **however** you want.

```elm
module Factory exposing
    ( Factory, createCarFactory, createGreenCarFactory
    , Car, electricCar, hydrogenCar, dieselCar
    )

type Car = ElectricCar | HydrogenCar | DieselCar
createCarFactory : (data -> List Car) -> Factory
createGreenCarFactory : (data -> List Car) -> Factory

electricCar = ElectricCar
hydrogenCar = HydrogenCar
dieselCar = DieselCar
```

Below is an example of how the API could be used. If this code works for you, you can see this as a check that your solution works:

```elm
import Factory exposing (Factory)

-- OK. Notice that there are different variants of the car in the resulting list
factory : Factory
factory =
	Factory.createCarFactory
    	(\_ ->
			[ Factory.dieselCar
			, Factory.electricCar
			, Factory.hydrogenCar
			]
		)

-- Also OK
factory : Factory
factory =
  Factory.createGreenCarFactory
    	(\_ ->
			[ Factory.electricCar
			, Factory.hydrogenCar
			]
		)

-- NOT OK
factory : Factory
factory =
	Factory.createGreenCarFactory
    	(\_ ->
			[ Factory.dieselCar
			, Factory.electricCar
			, Factory.hydrogenCar
			]
		)
```

The last constraint is the important and interesting one.

Try solving this problem for yourself before reading on! (Hint: The article's title hints at a way to address to problem ;) )


(blank

spacing

so

you

won't

see

the

answer

accidentally)



## ~The~ My solution

The solution I went with is by adding a phantom type, which is set to a concrete type for diesel cars, and a unbounded value for the others. More concretely:

```elm
module Factory exposing
    ( Factory, createCarFactory, createGreenCarFactory
    , Car, electricCar, hydrogenCar, dieselCar
    )

type Car fuel = ElectricCar | HydrogenCar | DieselCar

type Polluting = Polluting
type Green = Green

createCarFactory : (data -> List Car) -> Factory

createGreenCarFactory : (data -> List Car) -> Factory

electricCar : Car fuel
electricCar = ElectricCar

hydrogenCar : Car fuel
hydrogenCar = HydrogenCar

dieselCar : Car Polluting
dieselCar = DieselCar

createCarFactory : (data -> List (Car fuel)) -> Factory

createGreenCarFactory : (data -> List (Car Green)) -> Factory
```

I have created a [repository with the solution](https://github.com/jfmengels/factory-example) already in place, which you can play with.

## How does this work?


The first thing we did was to add a phantom type to the `Car` type. A phantom type is a type variable (just like the `a` in `Maybe a`) that never appears in a type constructor (unlike the `a` in `Maybe a` which appears in the `Just a` variant).

Phantom types allows us to distinguish similar things that are the same under the hood, while allowing us to use the same set (or a subset) of functions to manipulate them. Here we want to be able to use different `Car`s like they are the same thing.

We make diesel cars distinguishable from the rest by specifying a value for the `Car`s phantom type (in the `diesel` declaration) as `Car Polluting`.

The trick here is that we make the electric and hydrogen cars indistinguishable from the others, by making them be generic car (`Car fuel`, notice the lower case `f` which it is a type variable. `Car a` would also work by the way).

Having `electricCar` and `hydrogenCar` be `Car fuel` means that they can be **any** kind of `Car`, so the following code will type-check just fine.

```elm
import Factory exposing (Car, Diesel)

car1 : Car Green
car1 = Factory.electricCar

car2 : Car Polluting
car2 = Factory.electricCar
```

That also means that you can mix it with other kinds of cars in a list and do `[ electricCar, dieselCar ]`.

Finally, we change the constraints on the cars that the factory functions can return. `createCarFactory` keeps it generic, meaning you can return any kind of car (as long as they can all be stored in the same list, which they are currently). `createGreenCarFactory` requires `Car Green`. This means that diesel cars, of type `Car Polluting` don't fit!

## Benefits of this approach

I won't be able to compare this approach with all the others, because there are several ways this problem could have solved. I like this solution because of several factors.

First of all, this is a type error, and that means it's the compiler that will do the complaining.

There is no error case the user has to handle. Because we know the factory will be valid, we don't need to return a `Maybe Factory` or a `Result error Factory`.
Neither the user nor the module need to do any runtime checks either, meaning there won't be a runtime performance cost.

But what I like the most is that we can change the constraints, like marking `hydrogenCar` as polluting and therefore not allowing it in `createGreenCarFactory`, without the code looking any different (it would be a breaking change though).


## A practical case

In `elm-review`, users create "rules" by providing functions that create errors. The two main ways to create errors are the [**error**](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#error) function and the [**errorForModule**](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#errorForModule) function. The former creates an error for the file currently being analyzed, while the latter creates an error for a specific file, given as an argument. An example of how they are used:

```elm
rule : Rule
rule =
	-- Simplified a bit, but this is the rough idea
    Rule.newProjectRuleSchema "RuleName" initialProjectContext
        |> Rule.withSimpleExpressionVisitor expressionVisitor
        |> Rule.withFinalProjectEvaluation finalEvaluationForProject
        |> Rule.fromProjectRuleSchema

expressionVisitor : Node Expression -> List Error
expressionVisitor node =
    case Node.value node of
        Expression.FunctionOrValue _ "XYZ" ->
            [ Rule.error
                { message = "XYZ should not be used"
                , details = [ "XYZ is dangerous because reasons" ]
                }
                (Node.range node)
            ]

        _ ->
            []

finalEvaluationForProject : ProjectContext -> List Error
finalEvaluationForProject projectContext =
	-- unusedFunctions gets the unused functions in each module
    unusedFunctions projectContext
        |> List.map
            (\{ moduleKey, functionName, range } ->
                Rule.errorForModule moduleKey
                    { message = "Function `" ++ functionName ++ "` is never used"
                    , details = [ "Bla bla bla" ]
                    }
                    range
            )
```

In most cases, you will want to use the `error` function, because you will usually raise errors for the current file

But there are cases where using it won't make sense and therefore will lead to unwanted behavior. When creating a "project" rule, which analyzes all of the project's files, you will provide functions to handle parts of the analysis where you are not in the context of a single file. For instance during the "final evaluation" for the project like in the example above. That is a phase where all the modules have been analyzed, and you can report things while having full knowledge of what happens in the project. But in this phase, calling `error` doesn't make much sense, since it won't have a file to be affected to automatically.

What I did to solve this problem is the technique described in the previous section: singling out and forbidding the use of `error` (`dieselCar`) inside some visitors (factories).

```elm
type Local = Local
type NonLocal = NonLocal

error : ErrorData -> Range -> Error Local

errorForModule : ModuleKey -> ErrorData -> Range -> Error anyTarget

withSimpleExpressionVisitor : (Node Expression -> List (Error anyTarget)) -> RuleSchema -> RuleSchema

withFinalProjectEvaluation : (ProjectContext -> List (Error NonLocal)) -> RuleSchema -> RuleSchema
```

(If you look at the package's API, you'll notice I did things a bit differently, but that's for another article ;) )

The alternatives I envisioned where to
- tgnore the errors
- replace them by a global error that makes elm-review stop

In both cases, I would add a big warning on the function's documentation, and I would have the test module fail the tests if an error was defined in such a context. But as much as I try to help the user with tests, that would only work for users that wrote tests, and wrote tests that triggered a misused kind of error.

The downside of the current method is that all errors now have a "useless" type variable, which in this case I find esthetically displeasing. But knowing that nobody will lose time, raise an issue or ask for help because they misused the function makes it all worth it.
