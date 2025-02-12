module Settings exposing
    ( author
    , canonicalUrl
    , locale
    , subtitle
    , title
    )

import LanguageTag.Language as Language
import LanguageTag.Region as Region


canonicalUrl : String
canonicalUrl =
    "https://jfmengels.net"


locale : Maybe ( Language.Language, Region.Region )
locale =
    Just ( Language.en, Region.us )


title : String
title =
    "jfmengels' blog"


subtitle : String
subtitle =
    "A blog starter kit created with elm-pages and TailwindCSS"


author : String
author =
    "Jeroen Engels"
