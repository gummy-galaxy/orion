import { Profiler, type ProfilerOnRenderCallback } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import App from '../components/App'
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

/** Seeds browser storage, which the canvas falls back to without an Orion server, with a generated canvas. */
function seed(cards: number) {
  localStorage.setItem('orion:v2', JSON.stringify(generateCanvas({ cards })))
  localStorage.setItem('orion:viewport:default', JSON.stringify({ x: 40, y: 40, zoom: 0.8 }))
  counters.reset()
  window.orionPerf = counters

  return {}
}

const meta = {
  title: 'Perf/Canvas',
  parameters: { layout: 'fullscreen' },
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
