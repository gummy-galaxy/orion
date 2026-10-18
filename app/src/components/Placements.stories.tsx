import type { Meta, StoryObj } from '@storybook/react-vite'
import App from './App'
import { writeDetail } from '../detail'
import type { Remote } from '../persist'
import { placementsCanvas } from './storySupport/placementsCanvas'

/** The canvas the stubbed server hands out, until the first edit. */
let served: Remote | null = null

/**
 * Stands in for `orion serve`. It serves the fixture once and accepts edits without applying them, then stops
 * answering reads, so the canvas keeps its own copy of every edit instead of reloading the fixture over it.
 */
function stubServer() {
  const originalFetch = globalThis.fetch
  let revision = 1

  globalThis.fetch = (input, init) => {
    const path = String(input)

    if (path === '/api/orion' && (init?.method ?? 'GET') === 'GET')
      return Promise.resolve(served ? Response.json({ ...served, revision }) : new Response(null, { status: 503 }))

    if (path === '/api/operations') {
      revision += 1
      served = null

      return Promise.resolve(Response.json({ revision }))
    }

    return originalFetch(input, init)
  }

  return () => {
    globalThis.fetch = originalFetch
    served = null
  }
}

function seed() {
  served = placementsCanvas()
  localStorage.removeItem('orion:v2')
  localStorage.setItem('orion:viewport:default', JSON.stringify({ x: 60, y: 60, zoom: 0.85 }))
  writeDetail('default', null)

  return {}
}

/**
 * Spike for #122: one card in many places. "Sign-in flow" and "Release notes" each appear in two groups, marked with
 * a count of their places. Hover one to light up its other copy, rename one in the inspector to see both change, and
 * drag a copy to watch its links move to whichever copy is nearest.
 */
const meta = {
  title: 'Spikes/Placements',
  parameters: { layout: 'fullscreen' },
  beforeEach: stubServer,
  loaders: [seed],
  decorators: [
    (Story) => (
      <div style={{ width: '100vw', height: '100vh' }}>
        <Story />
      </div>
    ),
  ],
  render: () => <App />,
} satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const OneCardInTwoGroups: Story = {}
