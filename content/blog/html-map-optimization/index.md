---
title: Html.map as an optimization
date: '2022-02-28T11:59:00.000Z'
---

![](RecursiveTree.jpeg)

In [The Elm Architecture](https://guide.elm-lang.org/architecture/), the `view` triggers events that are passed to the
`update` function through the intermediary of a `Msg`. If you click on the submit button, you get a `UserClickedThatButton`
msg, and in the `update` function you indicate what to do in response to that stimuli.


TODO Find example where it would make sense to trigger the computation inside Html (because you'd need to recompute something expensive)
TODO Find example where that computation would need to be made lazy

```elm
view : Model -> Html Msg
view model =
    Html.div [] (List.map viewEvent model.events)

viewEvent : Event -> Html Msg
viewEvent event =
    Html.div []
        [ Html.button
            [
            ]
            [ Html.text ("Inspect row " ++ Event.id event)]
        ]
```


---

`Html.map` is not the only location where you can do this. You can apply the same concept in event handler functions
as long as they are called lazily, such as [`Html.Events.onInput`](https://package.elm-lang.org/packages/elm/html/latest/Html-Events#onInput).

The closer you can apply this technique to the event itself the better, so if you have the choice to do this on `Html.map`
or in `Html.Events.onInput`, choose the latter. The problematic with using `Html.map` is that if you have several messages
that can be triggered by the same Html element, then you will have type conflicts. Those type conflicts can be worked
around but I don't think the result will be particularly pleasant. `onInput` on the other hand can apply this optimization
without bothering neighbouring event handlers.
