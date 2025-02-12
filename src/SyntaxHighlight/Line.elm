module SyntaxHighlight.Line exposing
    ( Line, Fragment, Highlight(..)
    , highlightLines, highlightDiffLines
    )

{-| A parsed highlighted line.

@docs Line, Fragment, Highlight


## Helpers

@docs highlightLines, highlightDiffLines

-}

import SyntaxHighlight.Style as Style


{-| A line holds information about its fragments and if is highlighted in any way.
-}
type alias Line =
    { fragments : List Fragment
    , highlight : Maybe Highlight
    }


{-| A fragment holds information about the text being styled, the style and additional class to be applied.
-}
type alias Fragment =
    { text : String
    , requiredStyle : Style.Required
    , additionalClass : String
    }


type Highlight
    = Normal
    | Add
    | Del


highlightLines : Maybe Highlight -> Int -> Int -> List Line -> List Line
highlightLines maybeHighlight start end lines =
    let
        length =
            List.length lines

        start_ =
            if start < 0 then
                length + start

            else
                start

        end_ =
            if end < 0 then
                length + end

            else
                end
    in
    List.indexedMap (highlightLinesHelp maybeHighlight start_ end_) lines


highlightDiffLines : List Line -> List Line
highlightDiffLines lines =
    List.map highlightLine lines


highlightLine : Line -> Line
highlightLine line =
    case line.fragments of
        [] ->
            line

        fragment :: restOfFragments ->
            if String.startsWith "-" fragment.text then
                let
                    newFragment : Fragment
                    newFragment =
                        { fragment | text = String.dropLeft 1 fragment.text }
                in
                { fragments = newFragment :: restOfFragments
                , highlight = Just Del
                }

            else if String.startsWith "+" fragment.text then
                let
                    newFragment : Fragment
                    newFragment =
                        { fragment | text = String.dropLeft 1 fragment.text }
                in
                { fragments = newFragment :: restOfFragments
                , highlight = Just Add
                }

            else
                line


highlightLinesHelp : Maybe Highlight -> Int -> Int -> Int -> Line -> Line
highlightLinesHelp maybeHighlight start end index line =
    if index >= start && index < end then
        { line | highlight = maybeHighlight }

    else
        line
