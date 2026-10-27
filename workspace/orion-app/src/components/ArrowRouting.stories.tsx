import type { Meta, StoryObj } from '@storybook/react-vite'
import { APPROACHES, PLUG_THRESHOLD, SIZES, THRESHOLD_RANGE } from '../routing/approaches'
import { ArrowRoutingSpike } from './ArrowRoutingSpike'

/**
 * Spike for #26: today's curves, libavoid, a lane router of our own, group bundles, and far links cut into stubs and
 * plugs, on one canvas built to be hard on arrows. Switch approaches and sizes in the panel or the controls, and drag
 * cards to feel the cost per frame.
 */
const meta = {
  title: 'Explorations/Arrow routing',
  component: ArrowRoutingSpike,
  parameters: { layout: 'fullscreen' },
  argTypes: {
    approach: { control: 'inline-radio', options: APPROACHES.map((approach) => approach.id) },
    size: { control: 'inline-radio', options: SIZES },
    threshold: { control: { type: 'range', ...THRESHOLD_RANGE } },
  },
  args: { approach: 'curves', size: 90, threshold: PLUG_THRESHOLD },
} satisfies Meta<typeof ArrowRoutingSpike>

export default meta
type Story = StoryObj<typeof meta>

export const Curves: Story = { args: { approach: 'curves' } }
export const Libavoid: Story = { args: { approach: 'libavoid' } }
export const Lanes: Story = { args: { approach: 'lanes' } }
export const Bundles: Story = { args: { approach: 'bundles' } }
export const Plugs: Story = { args: { approach: 'plugs' } }
export const PlugsAndBundles: Story = { args: { approach: 'plugBundles' } }
