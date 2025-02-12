module Api exposing (manifest, routes)

import ApiRoute exposing (ApiRoute)
import BackendTask exposing (BackendTask)
import Content.Blogpost exposing (Blogpost)
import FatalError exposing (FatalError)
import Head
import Html exposing (Html)
import Pages
import Pages.Manifest as Manifest
import Route exposing (Route)
import Rss
import Settings
import Time


routes :
    BackendTask FatalError (List Route)
    -> (Maybe { indent : Int, newLines : Bool } -> Html Never -> String)
    -> List (ApiRoute ApiRoute.Response)
routes getStaticRoutes htmlToString =
    [ rss
        { siteTagline = "Jeroen Engels' blog"
        , siteUrl = Settings.canonicalUrl
        , title = Settings.title
        , builtAt = Pages.builtAt
        , indexPage = []
        }
        postsBackendTask
    ]


postsBackendTask : BackendTask FatalError (List Rss.Item)
postsBackendTask =
    Content.Blogpost.allBlogposts
        |> BackendTask.map
            (List.map
                (\a ->
                    let
                        metadata : Content.Blogpost.Metadata
                        metadata =
                            a.metadata
                    in
                    { title = metadata.title
                    , description = Maybe.withDefault "" metadata.description
                    , url =
                        Route.Slug_ { slug = metadata.slug }
                            |> Route.routeToPath
                            |> String.join "/"
                    , categories = []
                    , author = List.map .name metadata.authors |> String.join ","
                    , pubDate = Rss.Date (Content.Blogpost.getPublishedDate metadata)
                    , content = Nothing
                    , contentEncoded = Nothing
                    , enclosure = Nothing
                    }
                )
            )


rss :
    { siteTagline : String
    , siteUrl : String
    , title : String
    , builtAt : Time.Posix
    , indexPage : List String
    }
    -> BackendTask FatalError (List Rss.Item)
    -> ApiRoute.ApiRoute ApiRoute.Response
rss options itemsRequest =
    ApiRoute.succeed
        (itemsRequest
            |> BackendTask.map
                (\items ->
                    Rss.generate
                        { title = options.title
                        , description = options.siteTagline
                        , url = options.siteUrl ++ "/" ++ String.join "/" options.indexPage
                        , lastBuildTime = options.builtAt
                        , generator = Just "elm-pages"
                        , items = items
                        , siteUrl = options.siteUrl
                        }
                )
        )
        |> ApiRoute.literal "rss.xml"
        |> ApiRoute.single
        |> ApiRoute.withGlobalHeadTags
            (BackendTask.succeed
                [ Head.rssLink "/rss.xml"
                ]
            )


manifest : Manifest.Config
manifest =
    Manifest.init
        { name = Settings.title
        , description = Settings.subtitle
        , startUrl = Route.Index |> Route.toPath
        , icons = []
        }
