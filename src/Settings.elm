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
    "Written by Jeroen Engels, author of [elm-review](https://elm-review.com/). If you like what you read or what I made, you can follow me on [BlueSky](https://bsky.app/profile/jfmengels.bsky.social)/[Mastodon](https://mastodon.cloud/@jfmengels) or [sponsor me](https://github.com/sponsors/jfmengels/) so that I can one day do more of this full-time ❤️"


author : String
author =
    "Jeroen Engels"
