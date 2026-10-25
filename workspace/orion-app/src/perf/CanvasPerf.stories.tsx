import { Profiler, type ProfilerOnRenderCallback } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import App from '../components/App'
import { writeDetail } from '../detail'
import type { Remote } from '../persist'
import { generateCanvas } from './fixture'

/** What the perf script reads back from the page: React commits and the time spent rendering them. */
export type PerfCounters = { commits: number; renderMs: number; reset: () => void }

declare global {
  interface Window {
    orionPerf?: PerfCounters
  }
}

const counters: PerfCounters = {
  commits: 0,
  renderMs: 0,
  reset() {
    counters.commits = 0
    counters.renderMs = 0
  },
}

const record: ProfilerOnRenderCallback = (_id, _phase, actualDuration) => {
  counters.commits += 1
  counters.renderMs += actualDuration
}

/** The canvas the stubbed server returns, set by each story's loader. */
let served: Remote | null = null

/**
 * Stands in for `orion serve`, which is the canvas's only store: the canvas loads from it, and edits go back to it as
 * operations. Other requests pass through and fail the way they do without a server.
 */
function stubServer() {
  const originalFetch = globalThis.fetch

  globalThis.fetch = (input, init) => {
    const path = String(input)

    if (served && path === '/api/orion' && (init?.method ?? 'GET') === 'GET') {
      return Promise.resolve(Response.json(served))
    }

    if (served && path === '/api/operations') {
      served = { ...served, revision: served.revision + 1 }

      return Promise.resolve(Response.json({ revision: served.revision }))
    }

    return originalFetch(input, init)
  }

  return () => {
    globalThis.fetch = originalFetch
    served = null
  }
}

/** Serves a generated canvas from the stubbed server. Every group shows open so the profile covers every card. */
function seed(cards: number) {
  served = { ...generateCanvas({ cards }), revision: 1, settings: {} }
  localStorage.setItem('orion:viewport:default', JSON.stringify({ x: 40, y: 40, zoom: 0.8 }))
  // Named rather than left to the defaults, since this harness also runs over base revisions with older defaults.
  localStorage.setItem('orion:theme', 'vibrant')
  localStorage.setItem('orion:skin', 'trading')
  writeDetail('default', null)
  counters.reset()
  window.orionPerf = counters

  return {}
}

const meta = {
  title: 'Perf/Canvas',
  parameters: { layout: 'fullscreen' },
  beforeEach: stubServer,
  decorators: [
    (Story) => (
      <div style={{ width: '100vw', height: '100vh' }}>
        <Story />
      </div>
    ),
  ],
  render: () => (
    <Profiler id="canvas" onRender={record}>
      <App />
    </Profiler>
  ),
} satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Cards1000: Story = { loaders: [() => seed(1000)] }

export const Cards5000: Story = { loaders: [() => seed(5000)] }
