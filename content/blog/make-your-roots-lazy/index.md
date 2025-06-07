---
title: Make your roots lazy
slug: make-your-roots-lazy
published: "2025-06-07"
---

I mentioned in my article about [how Html.Lazy works](/caching-behind-elm-lazy) that it was a good idea to use lazy at the root of your application.

Using `Browser.element`:

```elm
main =
  Browser.element
    { view = Html.Lazy.lazy view
    -- ...
    }
```

Or for `Browser.application`/`Browser.document`:

```elm
main =
  Browser.application
    { view = view
    -- ...
    }

view model =
  { title = "My website"
  , body = Html.Lazy.lazy viewBody model
  }
```

Let's start with the simple premise that your root `view` is a reasonably large function and that therefore skipping its computation is usually good for performance. `Html.Lazy` can help with just that when the `Model` doesn't change during the `update`.

## Model doesn't always change

While changing the `Model` is the main thing the `update` function does, there are a number of cases where the `Model` doesn't get changed.

One example is when we handle a `Msg` by only returning a `Cmd`. For instance, to refresh some data:

```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    RefreshData ->
      ( model
      , httpRequestToRefreshData ()
      )

subscriptions : Model -> Sub Msg
subscriptions =
  Time.every 60000 RefreshData
```

In this example I've done it through a subscription, but it could also be as a reaction to a button click or something similar.

It is possible you'd like to change the `Model` to show the user some data is being loaded, but that will depend on the use-case. A specific example is when a social media website will silently check if there is new content, and they'd show a banner to tell you if they found new one (Twitter did in the okay days, I guess X still does).

Another example is handling messages where you wish not to do anything. I often encounter this when using [`Browser.Dom.focus`](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Dom#focus) or [`Browser.Dom.blur`](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Dom#blur): we get a message indicating whether the focusing/blurring succeeded or failed, but there's nothing I want to do with that information—even if it somehow failed—so I end up ignoring it.

```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    ShowItemButtonWasClicked ->
      ( { model | showItem = True }
      , Browser.Dom.focus "item"
        |> Task.attempt (\_ -> ItemGotFocus)
      )

    ItemGotFocus ->
      ( model, Cmd.none )
```

## No view call after update

In such cases, if the `Model` doesn't change, then the result of `view` will be the same, therefore it would be a shame to call it again.

At one point, I believed that the Elm runtime would do that: avoid calling `view` after `update` when the value of `Model` hasn't changed. Turns out, it doesn't. But adding a `Html.Lazy` at the very root does close to the same effect.

The root view will still get called, but since the entire function is hidden behind a lazy check that will figure out nothing has changed, our `view` function that is wrapped in `lazy` will not get computed. The diff will be empty, and therefore the runtime will try to apply an empty list of patches, which will be fast as well. It's not entirely cancelled but it's pretty much the same.

As seen in the previous article, the way lazy is designed is really cheap: the check is fast and there is barely any added memory allocation. Given all of that, it would be a shame not to use it.

## Nested TEA

The elephant in the room is the common pattern of nesting "The Elm Architecture". That very commonly contains code like this:

```elm
update : Msg -> Model -> Model
update msg model =
  case msg of
    X subMsg ->
      { model | x = X.update subMsg model.x }
```

Unfortunately, this code always creates a new `Model`, which means that lazy will fail on the next render if it takes the model as an argument.

Some projects have an architecture where you have this kind of pattern in all branches of the root `update`, which makes it impossible for the lazy check to ever succeed. Similarly, if you really do update the `Model` in all branches, then adding laziness won't be useful.

But, we can then move the lazy check to the sub-view. Add it to the root of the page(s) instead of `main` and you'll get most of the same benefits.

You can add it either at the definition of the view:

```elm
-- PageX.elm
view : Model -> Html Msg
view model =
  Html.Lazy.lazy viewBody model 

viewBody : Model -> Html Msg
viewBody model =
  Html.div [ ... ] [ ... ]
```

or at the call site:

```elm
-- Main.elm
view model =
  Html.div []
    [ Html.Lazy.lazy PageX.view model.pageXModel
    ]
```

(I don't yet know if one is necessarily better than the other)

Lazy is cheap. Sprinkle it to the different roots of your application: application root, page root, etc.

It's pretty much always an okay default unless you pass in other arguments that you know are going to be a new reference every time, like a config record:

```elm
-- Main.elm
view model =
  Html.div []
    [ Html.Lazy.lazy PageX.view
        { some = data }
        model.pageXModel
    ]
```

In which case you might want to look at using [this technique](/beyond-elm-lazy-arguments).

## Conclusion

Yes, there's often going to be record updates that lead to cache misses, but there are also places where it won't. Depends on how much nesting there is, and where messages appear.
And it's unlikely that this will change the overall performance of your application, since what most `update` branches will do is to alter the `Model`. 
Still, it's a really cheap check that could prevent a call to view and a diff+render, so I think it's pretty much always a good idea to put one in, unless you really have no branches where you don't create a new record.