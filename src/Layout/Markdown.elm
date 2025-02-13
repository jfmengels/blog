module Layout.Markdown exposing (blogpostToHtml, toHtml)

import Ansi.Log
import Array
import Html exposing (Html)
import Html.Attributes as Attrs
import Html.Lazy
import Markdown.Block as Block
import Markdown.Parser
import Markdown.Renderer exposing (defaultHtmlRenderer)
import Parser exposing (DeadEnd)
import Phosphor
import String.Normalize
import Svg.Attributes as SvgAttrs
import SyntaxHighlight


language : Maybe String -> String -> Result (List DeadEnd) SyntaxHighlight.HCode
language lang source =
    case Maybe.map (String.split ",") lang of
        Just ("elm" :: otherLangs) ->
            source
                |> SyntaxHighlight.elm
                |> Result.map (highlightLinesIfDiff otherLangs)

        Just ("css" :: otherLangs) ->
            source
                |> SyntaxHighlight.css
                |> Result.map (highlightLinesIfDiff otherLangs)

        Just ("sql" :: otherLangs) ->
            source
                |> SyntaxHighlight.sql
                |> Result.map (highlightLinesIfDiff otherLangs)

        Just ("xml" :: otherLangs) ->
            source
                |> SyntaxHighlight.xml
                |> Result.map (highlightLinesIfDiff otherLangs)

        Just ("html" :: otherLangs) ->
            source
                |> SyntaxHighlight.xml
                |> Result.map (highlightLinesIfDiff otherLangs)

        Just ("nix" :: otherLangs) ->
            source
                |> SyntaxHighlight.nix
                |> Result.map (highlightLinesIfDiff otherLangs)

        Just ("json" :: otherLangs) ->
            source
                |> SyntaxHighlight.json
                |> Result.map (highlightLinesIfDiff otherLangs)

        Just ("python" :: otherLangs) ->
            source
                |> SyntaxHighlight.python
                |> Result.map (highlightLinesIfDiff otherLangs)

        Just otherLangs ->
            source
                |> SyntaxHighlight.noLang
                |> Result.map (highlightLinesIfDiff otherLangs)

        Nothing ->
            SyntaxHighlight.noLang source


highlightLinesIfDiff : List String -> SyntaxHighlight.HCode -> SyntaxHighlight.HCode
highlightLinesIfDiff otherLangs hcode =
    if List.member "diff" otherLangs then
        SyntaxHighlight.highlightDiff hcode

    else
        hcode


syntaxHighlight : { a | language : Maybe String, body : String } -> Html msg
syntaxHighlight codeBlock =
    let
        sanitiseCodeBlock : String
        sanitiseCodeBlock =
            if String.endsWith "\n" codeBlock.body then
                String.dropRight 1 codeBlock.body

            else
                codeBlock.body
    in
    Html.div [ Attrs.class "no-prose mt-4" ]
        [ if codeBlock.language == Just "ansi" then
            Html.Lazy.lazy renderAnsi sanitiseCodeBlock

          else
            language codeBlock.language sanitiseCodeBlock
                |> Result.map (SyntaxHighlight.toBlockHtml (Just 1))
                |> Result.withDefault
                    (Html.pre [] [ Html.code [] [ Html.text sanitiseCodeBlock ] ])
        ]


renderAnsi : String -> Html msg
renderAnsi source =
    let
        model : Ansi.Log.Model
        model =
            Ansi.Log.update source (Ansi.Log.init Ansi.Log.Cooked)
    in
    Html.pre []
        [ Html.code [ Attrs.class "terminal" ]
            (Array.toList (Array.map (Html.Lazy.lazy Ansi.Log.viewLine) model.lines))
        ]


renderer : Markdown.Renderer.Renderer (Html msg)
renderer =
    Markdown.Renderer.defaultHtmlRenderer


blogpostRenderer : Markdown.Renderer.Renderer (Html msg)
blogpostRenderer =
    let
        headingElement level id =
            case level of
                Block.H1 ->
                    Html.h1 [ Attrs.id id ]

                Block.H2 ->
                    Html.h2 [ Attrs.id id ]

                Block.H3 ->
                    Html.h3 [ Attrs.id id ]

                Block.H4 ->
                    Html.h4 [ Attrs.id id ]

                Block.H5 ->
                    Html.h5 [ Attrs.id id ]

                Block.H6 ->
                    Html.h6 [ Attrs.id id ]
    in
    { defaultHtmlRenderer
        | heading =
            \{ level, rawText, children } ->
                let
                    id =
                        String.Normalize.slug rawText
                in
                headingElement level
                    id
                    [ Html.a
                        [ Attrs.href <| "#" ++ id
                        , Attrs.class "not-prose group "
                        , Attrs.attribute "aria-label" <| "Permalink for " ++ rawText
                        ]
                        [ Phosphor.link Phosphor.Thin
                            |> Phosphor.toHtml [ SvgAttrs.class "text-primary-300 inline-block text-xl mr-2" ]
                        , Html.span [ Attrs.class "group-hover:underline decoration-primary-500" ] children
                        ]
                    ]
        , codeSpan =
            \context ->
                Html.code [ Attrs.class "not-prose" ] [ Html.text context ]
        , codeBlock =
            \block ->
                syntaxHighlight block
    }


blogpostToHtml : String -> List (Html msg)
blogpostToHtml markdownString =
    markdownString
        |> Markdown.Parser.parse
        |> Result.mapError (\_ -> "Markdown error.")
        |> Result.andThen
            (\blocks ->
                Markdown.Renderer.render
                    blogpostRenderer
                    blocks
            )
        |> Result.withDefault [ Html.text "failed to read markdown" ]


toHtml : String -> List (Html msg)
toHtml markdownString =
    markdownString
        |> Markdown.Parser.parse
        |> Result.mapError (\_ -> "Markdown error.")
        |> Result.andThen
            (\blocks ->
                Markdown.Renderer.render
                    renderer
                    blocks
            )
        |> Result.withDefault [ Html.text "failed to read markdown" ]
