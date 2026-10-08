import type { Meta, StoryObj } from '@storybook/react-vite'
import { GhostView } from './GhostView'
import { StoryGraph } from './storySupport/StoryGraph'
import { ghost } from './storySupport/data'

const meta = { title: 'Canvas/Cards and edges/GhostView' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = { render: () => <StoryGraph nodes={[ghost]} nodeTypes={{ ghost: GhostView }} /> }
