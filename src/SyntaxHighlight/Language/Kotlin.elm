module SyntaxHighlight.Language.Kotlin exposing
    ( Syntax(..)
    ,  syntaxToStyle
       -- Exposing for test purposes

    , toLines
    , toRevTokens
    )

import Parser exposing ((|.), DeadEnd, Parser, Step(..), andThen, backtrackable, getChompedString, loop, map, oneOf, succeed, symbol)
import Regex exposing (Regex)
import Set exposing (Set)
import SyntaxHighlight.Language.Helpers exposing (Delimiter, chompIfThenWhile, delimited, escapable, isEscapable, isLineBreak, isSpace, isWhitespace, thenChompWhile)
import SyntaxHighlight.Language.Type as T
import SyntaxHighlight.Line exposing (Line)
import SyntaxHighlight.Line.Helpers as Line
import SyntaxHighlight.Style as Style exposing (Required(..))


type alias Token =
    T.Token Syntax


type Syntax
    = Number
    | String
    | Keyword
    | Operator
    | Function
    | DeclarationKeyword
    | Param
    | Punctuation
    | Literal


toLines : String -> Result (List DeadEnd) (List Line)
toLines =
    Parser.run toRevTokens
        >> Result.map (Line.toLines syntaxToStyle)


toRevTokens : Parser (List Token)
toRevTokens =
    loop [] mainLoop


mainLoop : List Token -> Parser (Step (List Token) (List Token))
mainLoop revTokens =
    oneOf
        [ space
            |> map (\n -> Loop (n :: revTokens))
        , lineBreak
            |> map (\n -> Loop (n :: revTokens))
        , punctuationChar
            |> map (\n -> Loop (n :: revTokens))
        , number
            |> map (\n -> Loop (n :: revTokens))
        , comment
            |> map (\n -> Loop (n ++ revTokens))
        , stringLiteral
            |> andThen (\n -> loop (n ++ revTokens) stringBody)
            |> map Loop
        , chompIfThenWhile isIdentifierChar
            |> getChompedString
            |> andThen (keywordParser revTokens)
            |> map Loop
        , succeed (Done revTokens)
        ]


isIdentifierChar : Char -> Bool
isIdentifierChar c =
    not
        (isWhitespace c
            || isPunctuationChar c
        )


stringBody : List Token -> Parser (Step (List Token) (List Token))
stringBody revTokens =
    oneOf
        [ whitespaceOrCommentStep revTokens
        , stringLiteral |> map (\s -> Loop (s ++ revTokens))
        , succeed (Done revTokens)
        ]


punctuationChar : Parser Token
punctuationChar =
    chompIfThenWhile isPunctuationChar
        |> getChompedString
        |> map (\b -> ( T.C Punctuation, b ))


isPunctuationChar : Char -> Bool
isPunctuationChar c =
    Set.member c punctuatorSet


punctuatorSet : Set Char
punctuatorSet =
    Set.fromList [ '{', '}', '(', ')', '[', ']', '.', ',', ':', ';' ]


isDeclarationKeyword : String -> Bool
isDeclarationKeyword str =
    Set.member str declarationKeywordSet


declarationKeywordSet : Set String
declarationKeywordSet =
    Set.fromList
        [ "var"
        , "val"
        , "vararg"
        ]



-- Keywords


keywordParser : List Token -> String -> Parser (List Token)
keywordParser revTokens s =
    if isOperator s then
        succeed (( T.C Operator, s ) :: revTokens)

    else if isFunction s then
        loop (( T.C DeclarationKeyword, s ) :: revTokens) functionDeclarationLoop

    else if isKeyword s then
        succeed (( T.C Keyword, s ) :: revTokens)

    else if isLiteral s then
        succeed (( T.C Literal, s ) :: revTokens)

    else if isDeclarationKeyword s then
        succeed (( T.C DeclarationKeyword, s ) :: revTokens)

    else
        succeed (( T.Normal, s ) :: revTokens)


functionDeclarationLoop : List Token -> Parser (Step (List Token) (List Token))
functionDeclarationLoop revTokens =
    oneOf
        [ whitespaceOrCommentStep revTokens
        , chompIfThenWhile isIdentifierNameChar
            |> getChompedString
            |> map (\b -> Loop (( T.C Function, b ) :: revTokens))
        , symbol "*"
            |> map (\_ -> Loop (( T.C Keyword, "*" ) :: revTokens))
        , succeed (Done revTokens)
        ]


argLoop : List Token -> Parser (Step (List Token) (List Token))
argLoop revTokens =
    oneOf
        [ whitespaceOrCommentStep revTokens
        , chompIfThenWhile (\c -> not (isCommentChar c || isWhitespace c || c == ',' || c == ')'))
            |> getChompedString
            |> map (\b -> Loop (( T.C Param, b ) :: revTokens))
        , chompIfThenWhile (\c -> c == '/' || c == ',')
            |> getChompedString
            |> map (\b -> Loop (( T.Normal, b ) :: revTokens))
        , succeed (Done revTokens)
        ]


isKeyword : String -> Bool
isKeyword =
    Regex.contains keywordPattern


keywordPattern : Regex
keywordPattern =
    "^(actual|abstract|annotation|break|by|catch|class|companion|const|constructor|continue|coroutine|crossinline|data|delegate|dynamic|do|else|enum|expect|external|final|finally|for|fun|get|if|import|infix|inline|interface|internal|lazy|lateinit|native|object|open|operator|out|override|package|private|protected|public|reified|return|sealed|set|super|suspend|tailrec|this|throw|try|typealias|typeof|when|while|yield)$"
        |> Regex.fromStringWith { caseInsensitive = False, multiline = False }
        |> Maybe.withDefault Regex.never


isLiteral : String -> Bool
isLiteral str =
    Set.member str literalSet


literalSet : Set String
literalSet =
    Set.fromList [ "false", "true", "null" ]


isFunction : String -> Bool
isFunction =
    (==) "fun"


isOperator : String -> Bool
isOperator =
    Regex.contains operatorPattern


operatorPattern : Regex
operatorPattern =
    "^([=!<>\\+]=?|\\+|\\|\\||&&|as\\??|!?in|!?is)$"
        |> Regex.fromStringWith { caseInsensitive = False, multiline = False }
        |> Maybe.withDefault Regex.never



-- Strings


stringLiteral : Parser (List Token)
stringLiteral =
    oneOf
        [ multilineString
        , quote
        , doubleQuote
        ]


quote : Parser (List Token)
quote =
    delimited quoteDelimiter


quoteDelimiter : Delimiter Token
quoteDelimiter =
    { start = "'"
    , end = "'"
    , isNestable = False
    , defaultMap = \b -> ( T.C String, b )
    , innerParsers = [ lineBreakList, ktEscapable ]
    , isNotRelevant = \c -> not (isLineBreak c || isEscapable c)
    }


multilineString : Parser (List Token)
multilineString =
    delimited
        { quoteDelimiter
            | start = "\"\"\""
            , end = "\"\"\""
        }


doubleQuote : Parser (List Token)
doubleQuote =
    delimited
        { quoteDelimiter
            | start = "\""
            , end = "\""
        }


isStringLiteralChar : Char -> Bool
isStringLiteralChar c =
    c == '\'' || c == '"'



-- Comments


comment : Parser (List Token)
comment =
    oneOf
        [ inlineComment
        , multilineComment
        ]


inlineComment : Parser (List Token)
inlineComment =
    [ "//" ]
        |> List.map (symbol >> thenChompWhile (not << isLineBreak) >> getChompedString >> map (\b -> [ ( T.Comment, b ) ]))
        |> oneOf


multilineComment : Parser (List Token)
multilineComment =
    delimited
        { start = "/*"
        , end = "*/"
        , isNestable = False
        , defaultMap = \b -> ( T.Comment, b )
        , innerParsers = [ lineBreakList ]
        , isNotRelevant = not << isLineBreak
        }



-- Helpers


whitespaceOrCommentStep : List Token -> Parser (Step (List Token) (List Token))
whitespaceOrCommentStep revTokens =
    oneOf
        [ space |> map (\s -> Loop (s :: revTokens))
        , lineBreak
            |> map (\s -> s :: revTokens)
            |> andThen checkContext
        , comment |> map (\s -> Loop (s ++ revTokens))
        ]


checkContext : List Token -> Parser (Step (List Token) (List Token))
checkContext revTokens =
    oneOf
        [ whitespaceOrCommentStep revTokens
        , succeed (Done revTokens)
        ]


space : Parser Token
space =
    chompIfThenWhile isSpace
        |> getChompedString
        |> map (\b -> ( T.Normal, b ))


lineBreak : Parser Token
lineBreak =
    symbol "\n"
        |> map (\_ -> ( T.LineBreak, "\n" ))


lineBreakList : Parser (List Token)
lineBreakList =
    symbol "\n"
        |> map (\_ -> [ ( T.LineBreak, "\n" ) ])


number : Parser Token
number =
    oneOf
        [ hexNumber
        , SyntaxHighlight.Language.Helpers.number
        ]
        |> getChompedString
        |> map (\b -> ( T.C Number, b ))


hexNumber : Parser ()
hexNumber =
    succeed ()
        |. backtrackable (symbol "0x")
        |. chompIfThenWhile Char.isHexDigit


ktEscapable : Parser (List Token)
ktEscapable =
    escapable
        |> getChompedString
        |> map (\b -> [ ( T.C Function, b ) ])


isCommentChar : Char -> Bool
isCommentChar c =
    c == '/'


isIdentifierNameChar : Char -> Bool
isIdentifierNameChar c =
    not
        (isPunctuationChar c
            || isStringLiteralChar c
            || isCommentChar c
            || isWhitespace c
        )


syntaxToStyle : Syntax -> ( Style.Required, String )
syntaxToStyle syntax =
    case syntax of
        Number ->
            ( Style1, "kt-n" )

        String ->
            ( Style2, "kt-s" )

        DeclarationKeyword ->
            ( Style3, "kt-dk" )

        Keyword ->
            ( Style3, "kt-k" )

        Operator ->
            ( Style4, "kt-o" )

        Function ->
            ( Style5, "kt-f" )

        Punctuation ->
            ( Style6, "kt-pu" )

        Literal ->
            ( Style7, "kt-l" )

        Param ->
            ( Style7, "kt-pa" )
