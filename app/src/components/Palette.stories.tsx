import type { Meta, StoryObj } from '@storybook/react-vite'
import { Palette } from './Palette'
import { group, task } from './storySupport/data'

const meta = { title: 'Interaction/Overlays/Palette', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <Palette
      nodes={[group, task]}
      commands={[{ id: 'new-note', label: 'New note', detail: 'Canvas', run: () => {} }]}
      jumpTo={() => {}}
      open={() => {}}
      close={() => {}}
    />
  ),
}
