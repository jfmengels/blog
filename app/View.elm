module View exposing
    ( View, map
    , freeze, freezableToHtml, htmlToFreezable, Freezable
    )

{-|

@docs View, map
@docs freeze, freezableToHtml, htmlToFreezable, Freezable

-}

import Html exposing (Html)


{-| -}
type alias View msg =
    { title : String
    , body : List (Html msg)
    }


{-| -}
map : (msg1 -> msg2) -> View msg1 -> View msg2
map fn doc =
    { title = doc.title
    , body = List.map (Html.map fn) doc.body
    }


{-| The type of content that can be frozen. Must produce no messages (Never).
-}
type alias Freezable =
    Html Never


{-| Convert Freezable content to plain Html for server-side rendering.
-}
freezableToHtml : Freezable -> Html Never
freezableToHtml =
    identity


{-| Convert plain Html back to Freezable for client-side adoption.
-}
htmlToFreezable : Html Never -> Freezable
htmlToFreezable =
    identity


{-| Freeze content so it's rendered at build time and adopted on the client.

Frozen content:

  - Is rendered at build time (or server-render time) and included in the HTML
  - Is adopted by the client without re-rendering
  - Has its rendering code and dependencies eliminated from the client bundle (DCE)

The content must be `Html Never` (no event handlers allowed).

-}
freeze : Freezable -> Html msg
freeze content =
    content
        |> freezableToHtml
        |> htmlToFreezable
        |> Html.map never
