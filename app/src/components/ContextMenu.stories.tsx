import type { Meta, StoryObj } from '@storybook/react-vite'
import { ContextMenu } from './ContextMenu'

const meta = { title: 'Interaction/Overlays/ContextMenu', parameters: { layout: 'fullscreen' } } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <ContextMenu
      x={120}
      y={120}
      close={() => {}}
      items={[{ label: 'Open', hint: '↵', run: () => {} }, 'divider', { label: 'Delete', danger: true, run: () => {} }]}
    />
  ),
}
