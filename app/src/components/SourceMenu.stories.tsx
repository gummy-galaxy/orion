import type { Meta, StoryObj } from '@storybook/react-vite'
import { SourceMenu } from './SourceMenu'
import { source } from './storySupport/data'

const meta = { title: 'Interaction/Overlays/SourceMenu', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <div style={{ padding: 80 }}>
      <SourceMenu domain="github.com" sources={[source]} />
    </div>
  ),
}
