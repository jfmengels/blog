module Shared exposing (Data, Model, Msg(..), template)

import BackendTask exposing (BackendTask)
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html exposing (Html)
import Html.Attributes as Attrs
import Layout
import Pages.Flags
import Pages.PageUrl exposing (PageUrl)
import Route exposing (Route)
import SharedTemplate exposing (SharedTemplate)
import UrlPath exposing (UrlPath)
import View exposing (View)


template : SharedTemplate Msg Model Data msg
template =
    { init = init
    , update = update
    , view = view
    , data = data
    , subscriptions = subscriptions
    , onPageChange = Nothing
    }


type Msg
    = MenuClicked


type alias Data =
    ()


type alias Model =
    { showMenu : Bool
    }


init :
    Pages.Flags.Flags
    ->
        Maybe
            { path :
                { path : UrlPath
                , query : Maybe String
                , fragment : Maybe String
                }
            , metadata : route
            , pageUrl : Maybe PageUrl
            }
    -> ( Model, Effect Msg )
init _ _ =
    ( { showMenu = False }
    , Effect.none
    )


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        MenuClicked ->
            ( { model | showMenu = not model.showMenu }, Effect.none )


subscriptions : UrlPath -> Model -> Sub Msg
subscriptions _ _ =
    Sub.none


data : BackendTask FatalError Data
data =
    BackendTask.succeed ()


view :
    Data
    ->
        { path : UrlPath
        , route : Maybe Route
        }
    -> Model
    -> (Msg -> msg)
    -> View msg
    -> { body : List (Html msg), title : String }
view _ _ model toMsg pageView =
    { body = body model.showMenu (toMsg MenuClicked) pageView.body
    , title = pageView.title
    }


body : Bool -> msg -> List (Html msg) -> List (Html msg)
body showMenu onMenuToggle pageViewBody =
    [ Html.div [ Attrs.class "mx-auto max-w-3xl px-4 sm:px-6 xl:max-w-5xl xl:px-0" ]
        [ Html.div [ Attrs.class "flex h-screen flex-col justify-between font-sans" ]
            [ Html.header
                [ Attrs.class "flex items-center justify-between py-10"
                ]
                [ Layout.viewLogo
                , Layout.viewMenu showMenu onMenuToggle
                ]
            , Html.main_ [ Attrs.class "w-full mb-auto" ] pageViewBody
            , Layout.viewFooter
            ]
        ]
    ]
