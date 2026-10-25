import type { Meta, StoryObj } from '@storybook/react-vite'
import type { ImageNode } from '../model'
import { ImageView } from './ImageView'
import { StoryGraph } from './storySupport/StoryGraph'

const preview = `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><rect width="256" height="256" fill="#e8dcbf"/><circle cx="128" cy="112" r="72" fill="#76a88e"/><path d="M32 205 112 112l52 52 34-39 42 80" fill="none" stroke="#315b6c" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/></svg>`

const meta = {
  title: 'Canvas/Cards and edges/ImageView',
  beforeEach: () => {
    const originalFetch = globalThis.fetch

    globalThis.fetch = (input, init) =>
      String(input).startsWith('/api/images/story.png?')
        ? Promise.resolve(new Response(preview, { headers: { 'content-type': 'image/svg+xml' } }))
        : originalFetch(input, init)

    return () => {
      globalThis.fetch = originalFetch
    }
  },
} satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const image: ImageNode = {
  id: 'image-preview',
  type: 'image',
  position: { x: 120, y: 90 },
  width: 256,
  height: 256,
  data: { kind: 'image', label: 'Concept board', asset: 'story.png', canvas: 'sample' },
}

export const Default: Story = { render: () => <StoryGraph nodes={[image]} nodeTypes={{ image: ImageView }} /> }
export const MissingAsset: Story = {
  render: () => <StoryGraph nodes={[{ ...image, data: { ...image.data, asset: 'missing.png' } }]} nodeTypes={{ image: ImageView }} />,
}
