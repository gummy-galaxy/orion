import type { StorybookConfig } from '@storybook/react-vite'
import type { AliasOptions } from 'vite'

const PROFILING = { find: /^react-dom\/client$/, replacement: 'react-dom/profiling' }

const toList = (alias: AliasOptions | undefined) =>
  Array.isArray(alias) ? alias : Object.entries(alias ?? {}).map(([find, replacement]) => ({ find, replacement }))

const config: StorybookConfig = {
  stories: ['../src/components/**/*.stories.tsx', '../src/perf/**/*.stories.tsx'],
  addons: [],
  framework: '@storybook/react-vite',
  // Production React skips Profiler callbacks, so perf builds swap in the profiling renderer to count renders.
  viteFinal: (viteConfig) =>
    process.env.ORION_PERF === '1'
      ? { ...viteConfig, resolve: { ...viteConfig.resolve, alias: [PROFILING, ...toList(viteConfig.resolve?.alias)] } }
      : viteConfig,
}

export default config
