import React from 'react'
import { StaticQuery, graphql } from 'gatsby'
import profilePic from '../../content/assets/profile-pic.png'

import { rhythm } from '../utils/typography'

function Bio() {
  return (
    <StaticQuery
      query={bioQuery}
      render={data => {
        const { author, social } = data.site.siteMetadata
        return (
          <div
            style={{
              display: `flex`,
              marginBottom: rhythm(2.5),
            }}
          >
            <img
              src={profilePic}
              alt={author}
              style={{
                marginRight: rhythm(1 / 2),
                marginBottom: 0,
                width: 50,
                height: 50,
                borderRadius: `100%`,
              }}
            />
            <p>
              Written by <strong>{author}</strong>, author of{' '}
              <a href="https://package.elm-lang.org/packages/jfmengels/elm-review/latest/">
                elm-review
              </a>
              . If you like what you read, you can follow me on{' '}
              <a href={`https://twitter.com/${social.twitter}`}>Twitter</a> or <a href={"https://github.com/sponsors/jfmengels"}>sponsor me</a>.
            </p>
          </div>
        )
      }}
    />
  )
}

const bioQuery = graphql`
  query BioQuery {
    site {
      siteMetadata {
        author
        social {
          twitter
        }
      }
    }
  }
`

export default Bio
