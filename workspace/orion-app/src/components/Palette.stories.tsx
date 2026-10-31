import type { Meta, StoryObj } from '@storybook/react-vite'
import { Palette } from './Palette'
import { group, task } from './storySupport/data'

const meta = { title: 'Interaction/Overlays/Palette', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const commands = [
  { id: 'new-note', label: 'New note', detail: 'Canvas', hint: 'N', run: () => {} },
  { id: 'fit', label: 'Fit to screen', detail: 'View', hint: '⇧1', run: () => {} },
]

export const Default: Story = {
  render: () => (
    <Palette nodes={[group, task]} commands={commands} jumpTo={() => {}} open={() => {}} close={() => {}} />
  ),
}

export const Actions: Story = {
  render: () => (
    <Palette
      nodes={[group, task]}
      commands={commands}
      jumpTo={() => {}}
      open={() => {}}
      close={() => {}}
      initialQuery=">"
    />
  ),
}
