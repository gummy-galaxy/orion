import type { Meta, StoryObj } from '@storybook/react-vite'
import { SpikeBoard } from './SpikeBoard'
import { PRESETS } from '../selectionSpike/board'

const meta = {
  title: 'Spikes/Selection',
  component: SpikeBoard,
  parameters: { layout: 'fullscreen' },
  args: { showPointer: false },
} satisfies Meta<typeof SpikeBoard>

export default meta
type Story = StoryObj<typeof meta>

const presetOf = (id: string) => PRESETS.find((preset) => preset.id === id)!.gesture

/** Today's box selection, Space or middle-button pan, and ⇧/⌘ to add. */
export const Baseline: Story = { args: { initialGesture: presetOf('baseline') } }

export const Sweep: Story = { args: { initialGesture: presetOf('sweep') } }

export const Magnet: Story = { args: { initialGesture: presetOf('magnet') } }

export const Gather: Story = { args: { initialGesture: presetOf('gather') } }

export const RightDragPan: Story = { args: { initialGesture: presetOf('right-pan') } }

export const Modifiers: Story = { args: { initialGesture: presetOf('modifiers') } }
