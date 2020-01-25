--

Talk proposal

# Title proposals

The phantom type builder pattern
The phantom builder pattern
The haunted builder
Enjoying a nice API and flexible constraints with the phantom type builder pattern
Building things with phantoms
Working with phantom types, extensible records and the builder pattern.

## Summary

We will explore a way to write new Elm APIs

## The builder pattern, and its limits

This will be a rapid introduction to the builder pattern, what it looks like and some of the benefits.
Then we would explain what kind of constraints the builder pattern doesn't allow us to model, such as making some data mandatory only in some

## Extending the builder pattern using extensible records

- What a compiler error looks like
- The importance of good naming

## How to model different constraints

- Making things mandatory
- Requiring either of two things mandatory (require withA or withB)
- Forbidding a combination of two things (not having both withA and withB)
- Making things mandatory only when other things have been added (making withB mandatory if withA has been used)
- Ordering of operations
- Making

## Pros and cons

Pros:

- The API doesn't change from a normal builder pattern, and users won't see the constraints when they see the pattern put in use.
- You can remove "IMPORTANT NOTE" from your documentation, such as "don't use this on conjunction with". Don't warn about it, make it impossible.
- It is really easy to opt out of this when you do not manage to design fitting phantom types.

Cons:

- Depending on the number of constraints, the type signature will be quite hard to read
  - You can make this less problematic by having code examples in the documentation
- The more complex the constraints, the harder it is to make everything work out. Especially when refactoring your phantom types, you may make some unwanted things possible or some wanted things impossible.
  - Tip: Write down what you want to make impossible and what you want to keep possible
  - Have "compiler tests": Files that should compile, and files that shouldn't compile (with a given error message).

## Inspiration

- Robot button from Mars, from Brian Hicks
- elm-css phantom types discussion: https://github.com/rtfeldman/elm-css/issues/375

--

## Builder pattern

The builder pattern makes for a nice pattern for highly customizable elements.

Alternative syntaxes:

```elm
-- CONFIGURATION OBJECT
thing : A -> B -> Maybe C -> Thing
myThing =
  thing { a = someA, b = someB, c = Nothing }

-- OR
thing : { a : A, b : B, c : Maybe C } -> Thing
myThing =
  thing someA someB Nothing

-- WITH DEFAULT VALUE
thingDefaultValue : { a : A, b : B, c : Maybe C } -> Thing
thing : { a : A, b : B, c : Maybe C } -> Thing

myThing =
  thing { thingDefaultValue | a = someA }


-- WITH DEFAULT VALUE FUNCTION
thing : ({ a : A, b : B, c : Maybe C } -> { a : A, b : B, c : Maybe C }) -> Thing

-- WITH LIST
-- Makes it harder to enforce having a given value
-- Everything needs to be wrapped in the same type
type SubThing
  = WrappedA A
  | WrappedB B

thing : List SubThing -> Thing

myThing =
  thing (thingDefaultValue -> { thingDefaultValue | a = someA })

-- BUILDER PATTERN
thingSchema : A -> ThingSchema
withB : B -> ThingSchema -> ThingSchema
withXyz : ThingSchema -> ThingSchema
createThing : ThingSchema -> Thing

myThing =
  thingSchema someA
    |> withB someB
    |> withXyz
    |> createThing
```

## Builder pattern with phantom types / phantom constraints

With a regular construction pattern like `thing : A -> B -> Maybe C -> Thing`,
you have quite a lot of control over what gets created.

Let's say you have a room,
If you want one field

You can create different types of schemas that will end in , but they will
inherit

```elm
livingRoom : Room LivingRoom

storageRoom : Room StorageRoom

-- FUNCTIONS THAT WORK WITH ANY ROOM
withDoor : Door -> Room a -> Room a

-- FUNCTION THAT ONLY WORK ON A SELECT TYPE
withWindow : Window -> Room LivingRoom -> Room LivingRoom
```

With the example above, if you have more room types, you'll need one function to
add a window for every type of room that allows it.

Another way, is to use extensible records as the variable https://github.com/rtfeldman/elm-css/issues/375

```elm
type Supported = Supported
livingRoom : Room { windows: Supported }
withFurniture : List Furniture -> Room LivingRoom -> Room LivingRoom

storageRoom : Room {}

-- FUNCTIONS THAT WORK WITH ANY ROOM
withDoor : Door -> Room a -> Room a

-- FUNCTION THAT ONLY WORK ON A SELECT TYPE
withWindow : Window -> Room { a | windows: Supported } -> Room { a | windows: Supported }
```

Phantom constraints: Very configurable constraints for very configurable elements.

## How it works

When you say `type FooType a = FooValue`, that means that `FooValue` is a value of type `FooType a`, regardless of what `a` is.
So the following are all valid

```elm
with* : FooType a -> FooType a
with* foo =
  FooValue

with* : FooType a -> FooType {}
with* foo =
  FooValue

with* : FooType a -> FooType { a |}
with* foo =
  FooValue
```

But even though the phantom type is not used, the compiler will still enforce their constraints.

## Possible constraints

```elm
type Foo a =
  Foo

empty : Foo {}
empty =
    Foo

-- Add something
withA : Foo a -> Foo { a | a : () }
withA foo =
    Foo

-- Remove something (can't remove something that wasn't already there in the first place)
withoutA : Foo { a | a : () } -> Foo a
withoutA foo =
    Foo

-- Replace a field by another
withBinsteadOfA : Foo { a | a : () } -> Foo { a | b : () }
withBinsteadOfA foo =
    Foo

-- Replace a field's value by another
withSomeOtherA : Foo { a | a : () } -> Foo { a | a : {} }
withSomeOtherA foo =
    Foo

-- Replace the whole type variable by something else
withA : Foo a -> Foo Int
withA foo =
    Foo
```

In the implementation, the value needs to be (deconstructed and) reconstructed, otherwise the compiler will find a type mismatch.
That means that the type must be opaque, otherwise you lose the guarantees.

```elm
withA : Foo a -> Foo Int

-- Works
withA foo = Foo
withA (Foo foo) = (Foo { foo | a = 1 })

-- Noes not work
withA foo = foo
```

## Can't fool the compiler using List.foldl and an empty list

The initial value needs to already be of the resulting type.

Basically, we need to prove the list is non empty or provide a non-empty list in one form or another

```elm
withWindow : Window -> Room a -> Room { a | withWindow : () }
withWindow window room =
  -- ...
  room

withWindows : List Window -> Room a -> Room { a | withWindow : () }
withWindows windows room =
  List.foldl withWindow room windows
```

```
The 2nd argument to `foldl` is not what I expect:

71| List.foldl
72| (\visitor s -> Rule.withImportVisitor visitor s)
73|> schema
74| visitors

This `schema` value is a:

    Rule.ModuleRuleSchema anyType anything context

But `foldl` needs the 2nd argument to be:

    Rule.ModuleRuleSchema anyType { hasAtLeastOneVisitor : () } context
```

It's possible by deconstructing the value, but that means the type is not opaque.
