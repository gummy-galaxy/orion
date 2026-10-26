import { defineConfig } from 'vitepress'
import cliCommands from '../reference/cli/sidebar.json' with { type: 'json' }

export default defineConfig({
  title: 'Orion',
  description: 'One graph of everything you are juggling, for people and agents.',
  // The vibrant theme is dark only, like the app's.
  appearance: 'force-dark',
  cleanUrls: true,
  markdown: { image: { lazyLoading: true } },
  lastUpdated: true,
  head: [
    ['link', { rel: 'icon', type: 'image/png', href: '/logo.png' }],
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
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Reference', link: '/reference/', activeMatch: '^/reference/' },
      { text: 'Development', link: '/development/', activeMatch: '^/development/' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'Guide',
          items: [
            { text: 'Getting started', link: '/guide/getting-started' },
            { text: 'Concepts', link: '/guide/concepts' },
            { text: 'Using the canvas', link: '/guide/canvas' },
            { text: 'The command line', link: '/guide/command-line' },
            { text: 'Sources', link: '/guide/sources' },
            { text: 'Data and canvases', link: '/guide/data' },
            { text: 'Themes', link: '/guide/themes' },
            { text: 'Theme tokens', link: '/guide/tokens' },
            { text: 'Public surfaces', link: '/guide/surfaces' },
          ],
        },
      ],
      '/reference/': [
        { text: 'Reference', link: '/reference/' },
        { text: 'CLI', link: '/reference/cli/', items: cliCommands, collapsed: false },
        { text: 'MCP', link: '/reference/mcp' },
        {
          text: 'Syntax',
          collapsed: false,
          items: [
            { text: 'Queries', link: '/reference/query' },
            { text: 'Refs', link: '/reference/refs' },
            { text: 'Selectors', link: '/reference/selectors' },
          ],
        },
      ],
      '/development/': [
        { text: 'Development', link: '/development/' },
        { text: 'Charter', link: '/development/charter' },
        { text: 'Decisions', link: '/development/decisions' },
        { text: 'Origins', link: '/development/origins' },
        {
          text: 'Design',
          link: '/development/design/',
          collapsed: false,
          items: [
            { text: 'Canvas and layout', link: '/development/design/canvas-and-layout' },
            { text: 'Card identity', link: '/development/design/card-identity' },
            { text: 'Card skins', link: '/development/design/cards' },
            { text: 'Companion', link: '/development/design/companion' },
            { text: 'Gummy Galaxy and Orion', link: '/development/design/gummy-galaxy-and-orion' },
            { text: 'Gummy Galaxy concept art', link: '/development/design/gummy-galaxy-concept-art' },
            { text: 'Logo', link: '/development/design/logo' },
            { text: 'Motion and feel', link: '/development/design/motion-and-feel' },
            { text: 'Themes and skins', link: '/development/design/themes-and-skins' },
            { text: 'Trading cards', link: '/development/design/trading-cards' },
          ],
        },
        {
          text: 'Engineering',
          link: '/development/engineering/',
          collapsed: false,
          items: [
            { text: 'Adapters', link: '/development/engineering/adapters' },
            { text: 'Architecture', link: '/development/engineering/architecture' },
            { text: 'CLI and agents', link: '/development/engineering/cli-and-agents' },
            { text: 'Data and sync', link: '/development/engineering/data-and-sync' },
            { text: 'Interface audit', link: '/development/engineering/interface-audit' },
            { text: 'Performance', link: '/development/engineering/performance' },
          ],
        },
      ],
    },
    search: { provider: 'local' },
    outline: { level: [2, 3] },
    socialLinks: [{ icon: 'github', link: 'https://github.com/gummy-galaxy/orion' }],
    editLink: {
      pattern: 'https://github.com/gummy-galaxy/orion/edit/main/docs/:path',
    },
  },
})
