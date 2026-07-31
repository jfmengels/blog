module Route.Index exposing (ActionData, Data, Model, Msg, RouteParams, route)

import BackendTask exposing (BackendTask)
import Content.Blogpost exposing (Metadata)
import FatalError exposing (FatalError)
import Head
import Html
import Html.Attributes as Attrs
import Layout
import Layout.Blogpost
import Layout.Markdown
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatelessRoute)
import Settings
import Shared
import View exposing (View)


type alias Model =
    {}


type alias Msg =
    ()


type alias RouteParams =
    {}


type alias Data =
    { blogpostMetadata : List Metadata
    }


type alias ActionData =
    {}


route : StatelessRoute RouteParams Data ActionData
route =
    RouteBuilder.single
        { head = head
        , data = data
        }
        |> RouteBuilder.buildNoState { view = view }


data : BackendTask FatalError Data
data =
    Content.Blogpost.allBlogposts
        |> BackendTask.map (\allBlogposts -> List.map .metadata allBlogposts |> (\allMetadata -> { blogpostMetadata = allMetadata }))


head :
    App Data ActionData RouteParams
    -> List Head.Tag
head _ =
    Layout.seoHeaders


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> View (PagesMsg Msg)
view app _ =
    { title = Settings.title
    , body =
        --TODO move to layout part
        [ View.freeze (Html.p [ Attrs.class "prose text-lg leading-7 text-gray-500 dark:text-gray-400" ] (Layout.Markdown.toHtml subtitle))
        , View.freeze (Html.div [] <| List.map Layout.Blogpost.viewListItem app.data.blogpostMetadata)
        ]
    }


subtitle : String
subtitle =
    "Written by Jeroen Engels, author of [elm-review](https://elm-review.com/). If you like what you read or what I made, you can follow me on [BlueSky](https://bsky.app/profile/jfmengels.bsky.social)/[Mastodon](https://mastodon.cloud/@jfmengels) or [sponsor me](https://github.com/sponsors/jfmengels/) so that I can one day do more of this full-time ❤️"
