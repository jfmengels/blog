module Layout exposing (seoHeaders, view)

import Head exposing (Tag)
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attrs
import Html.Events as Events
import LanguageTag.Language as Language
import LanguageTag.Region as Region
import Pages.Url
import Route exposing (Route)
import Settings
import Svg
import Svg.Attributes as SvgAttrs
import UrlPath


seoHeaders : List Tag
seoHeaders =
    let
        imageUrl =
            [ "media", "blog-image.png" ] |> UrlPath.join |> Pages.Url.fromPath
    in
    Seo.summaryLarge
        { canonicalUrlOverride = Nothing
        , siteName = Settings.title
        , image =
            { url = imageUrl
            , alt = "logo"
            , dimensions = Just { width = 500, height = 333 }
            , mimeType = Nothing
            }
        , description = Settings.subtitle
        , locale = Just ( Language.en, Region.us )
        , title = Settings.title
        }
        |> Seo.website


menu : List { label : String, route : Route }
menu =
    [ { label = "About", route = Route.About }
    ]


logo : Html msg
logo =
    Html.div
        [ Attrs.class "mr-1 text-primary-600 dark:text-primary-500 flex gap-x-4 mr-4"
        ]
        [ Html.img
            [ Attrs.alt "avatar"
            , Attrs.attribute "loading" "lazy"
            , Attrs.width 38
            , Attrs.height 38
            , Attrs.attribute "decoding" "async"
            , Attrs.attribute "data-nimg" "1"
            , Attrs.class "h-12 w-12 hidden sm:block"
            , Attrs.style "color" "transparent"
            , Attrs.src "/images/logo.png"
            ]
            []
        , Html.img
            [ Attrs.alt "avatar"
            , Attrs.attribute "loading" "lazy"
            , Attrs.width 38
            , Attrs.height 38
            , Attrs.attribute "decoding" "async"
            , Attrs.attribute "data-nimg" "1"
            , Attrs.class "h-12 w-12 rounded-full hidden sm:block"
            , Attrs.style "color" "transparent"
            , Attrs.src "/images/authors/default.png"
            ]
            []
        ]


viewMainMenuItem : { label : String, route : Route } -> Html msg
viewMainMenuItem { label, route } =
    Route.link
        [ Attrs.class "hidden sm:block font-medium text-gray-900 dark:text-gray-100 hover:underline decoration-primary-500"
        ]
        [ Html.text label ]
        route


viewSideMainMenuItem : msg -> { label : String, route : Route } -> Html msg
viewSideMainMenuItem onMenuToggle { label, route } =
    Html.div
        [ Attrs.class "px-12 py-4"
        ]
        [ Route.link
            [ Attrs.class "text-2xl font-bold tracking-widest text-gray-900 dark:text-gray-100"
            , Events.onClick onMenuToggle
            ]
            [ Html.text label ]
            route
        ]


viewMenu : Bool -> msg -> Html msg
viewMenu showMenu onMenuToggle =
    let
        mainMenuItems =
            List.map viewMainMenuItem menu

        sideMenuItems =
            { label = "Home", route = Route.Index }
                :: menu
                |> List.map (viewSideMainMenuItem onMenuToggle)
    in
    Html.nav
        [ Attrs.class "flex items-center leading-5 space-x-4 sm:space-x-6"
        ]
        (mainMenuItems
            ++ [ Html.button
                    [ Attrs.attribute "aria-label" "Toggle Menu"
                    , Attrs.class "sm:hidden"
                    , Events.onClick onMenuToggle
                    ]
                    [ Svg.svg
                        [ SvgAttrs.viewBox "0 0 20 20"
                        , SvgAttrs.fill "currentColor"
                        , SvgAttrs.class "text-gray-900 dark:text-gray-100 h-8 w-8"
                        ]
                        [ Svg.path
                            [ SvgAttrs.fillRule "evenodd"
                            , SvgAttrs.d "M3 5a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 10a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM3 15a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z"
                            , SvgAttrs.clipRule "evenodd"
                            ]
                            []
                        ]
                    ]
               , Html.div
                    [ Attrs.class "fixed left-0 top-0 z-10 h-full w-full transform opacity-95 dark:opacity-[0.98] bg-white duration-300 ease-in-out dark:bg-gray-950"
                    , Attrs.classList
                        [ ( "translate-x-0", showMenu )
                        , ( "translate-x-full", not showMenu )
                        ]
                    ]
                    [ Html.div
                        [ Attrs.class "flex justify-end"
                        ]
                        [ Html.button
                            [ Attrs.class "mr-8 mt-11 h-8 w-8"
                            , Attrs.attribute "aria-label" "Toggle Menu"
                            , Events.onClick onMenuToggle
                            ]
                            [ Svg.svg
                                [ SvgAttrs.viewBox "0 0 20 20"
                                , SvgAttrs.fill "currentColor"
                                , SvgAttrs.class "text-gray-900 dark:text-gray-100"
                                ]
                                [ Svg.path
                                    [ SvgAttrs.fillRule "evenodd"
                                    , SvgAttrs.d "M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                                    , SvgAttrs.clipRule "evenodd"
                                    ]
                                    []
                                ]
                            ]
                        ]
                    , Html.div
                        [ Attrs.class "fixed mt-8 h-full"
                        ]
                        sideMenuItems
                    ]
               ]
        )


view : Bool -> msg -> List (Html msg) -> List (Html msg)
view showMenu onMenuToggle body =
    [ Html.div [ Attrs.class "mx-auto max-w-3xl px-4 sm:px-6 xl:max-w-5xl xl:px-0" ]
        [ Html.div [ Attrs.class "flex h-screen flex-col justify-between font-sans" ]
            [ Html.header
                [ Attrs.class "flex items-center justify-between py-10"
                ]
                [ Html.div []
                    [ Html.a
                        [ Attrs.attribute "aria-label" Settings.title
                        , Attrs.href "/"
                        ]
                        [ Html.div
                            [ Attrs.class "flex items-center justify-between"
                            ]
                            [ logo
                            , Html.div
                                [ Attrs.class "h-6 text-2xl font-semibold dark:text-white"
                                ]
                                [ Html.text Settings.title ]
                            ]
                        ]
                    ]
                , viewMenu showMenu onMenuToggle
                ]
            , Html.main_ [ Attrs.class "w-full mb-auto" ] body
            , Html.footer [ Attrs.class "py-8 flex flex-col items-center" ]
                [ Html.div
                    [ Attrs.class "mb-2 flex space-x-2 text-sm text-gray-500 dark:text-gray-400"
                    ]
                    [ Html.div []
                        [ Html.text Settings.author ]
                    , Html.div []
                        [ Html.text "•" ]
                    , Html.div []
                        [ Html.text "© 2025" ]
                    , Html.div []
                        [ Html.text "•" ]
                    , Html.a
                        [ Attrs.href "/"
                        , Attrs.class "hover:underline"
                        ]
                        [ Html.text Settings.title ]
                    ]
                ]
            ]
        ]
    ]
