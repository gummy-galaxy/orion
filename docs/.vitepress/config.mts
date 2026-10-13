import { defineConfig } from 'vitepress'
import cliCommands from '../reference/cli/sidebar.json' with { type: 'json' }

// GitHub Pages serves the site under the repository's name; local builds serve it from the root.
const base = process.env.DOCS_BASE ?? '/'

export default defineConfig({
  title: 'Orion',
  description: 'One graph of everything you are juggling, for people and agents.',
  base,
  // The vibrant theme is dark only, like the app's.
  appearance: 'force-dark',
  cleanUrls: true,
  lastUpdated: true,
  head: [
    ['link', { rel: 'icon', type: 'image/png', href: `${base}logo.png` }],
    ['link', { rel: 'preconnect', href: 'https://fonts.googleapis.com' }],
    ['link', { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' }],
    [
      'link',
      {
        rel: 'stylesheet',
        href: 'https://fonts.googleapis.com/css2?family=Unbounded:wght@500;700&family=Schibsted+Grotesk:wght@400;500;700&family=JetBrains+Mono:wght@400;500&display=swap',
      },
    ],
  ],
  themeConfig: {
    logo: '/logo.png',
    nav: [
      { text: 'Guide', link: '/guide/concepts' },
      { text: 'CLI', link: '/reference/cli/' },
      { text: 'MCP', link: '/reference/mcp' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'Guide',
          items: [
            { text: 'Concepts', link: '/guide/concepts' },
            { text: 'Public surfaces', link: '/guide/surfaces' },
          ],
        },
      ],
      '/reference/': [
        { text: 'CLI', link: '/reference/cli/', items: cliCommands, collapsed: false },
        { text: 'MCP', link: '/reference/mcp' },
      ],
    },
    search: { provider: 'local' },
    outline: { level: [2, 3] },
    socialLinks: [{ icon: 'github', link: 'https://github.com/vocksel/orion' }],
    editLink: {
      pattern: 'https://github.com/vocksel/orion/edit/main/docs/:path',
    },
  },
})
