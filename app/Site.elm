module Site exposing (config)

import BackendTask exposing (BackendTask)
import FatalError exposing (FatalError)
import Head
import MimeType
import Pages.Url
import Settings
import SiteConfig exposing (SiteConfig)


config : SiteConfig
config =
    { canonicalUrl = Settings.canonicalUrl
    , head = head
    }


head : BackendTask FatalError (List Head.Tag)
head =
    [ Head.metaName "viewport" (Head.raw "width=device-width,initial-scale=1")
    , Head.sitemapLink "/sitemap.xml"
    , Head.metaName "apple-mobile-web-app-capable" (Head.raw "yes")
    , Head.metaName "apple-mobile-web-app-status-bar-style" (Head.raw "black-translucent")
    , Head.icon [ ( 32, 32 ) ] MimeType.Png (Pages.Url.fromPath [ "favicon/favicon-32x32.png" ])
    , Head.icon [ ( 16, 16 ) ] MimeType.Png (Pages.Url.fromPath [ "favicon/favicon-16x16.png" ])
    ]
        |> BackendTask.succeed
