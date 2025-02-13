import Typography from 'typography'
import Wordpress2016 from 'typography-theme-wordpress-2016'

Wordpress2016.overrideThemeStyles = () => {
  return {
    'html': {
      'color-scheme': 'light dark',
    },
    '@media (prefers-color-scheme: light)': {
      ':root': {
        '--bg-code': 'rgba(255, 229, 100, 0.2)',
        '--text-code': '#1a1a1a'
      }
    },
    '@media (prefers-color-scheme: dark)': {
      'body': {
        'color': 'white'
      },
      ':root': {
        '--bg-code': 'rgba(0, 122, 204, 0.2)',
        '--text-code': '#d0d0ff'
      },
    },
    'a.gatsby-resp-image-link': {
      boxShadow: `none`,
    },
  }
}

delete Wordpress2016.googleFonts

const typography = new Typography(Wordpress2016)

// Hot reload typography in development.
if (process.env.NODE_ENV !== `production`) {
  typography.injectStyles()
}

export default typography
export const rhythm = typography.rhythm
export const scale = typography.scale
