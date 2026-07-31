module Settings exposing
    ( author
    , canonicalUrl
    , description
    , locale
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


description : String
description =
    "Articles by Jeroen Engels, mostly around Elm, static analysis and more generally programming"


author : String
author =
    "Jeroen Engels"
