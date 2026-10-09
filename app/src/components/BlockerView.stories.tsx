import type { Meta, StoryObj } from '@storybook/react-vite'
import { BLOCKER_HEIGHT, BLOCKER_WIDTH } from '../blocker'
import type { BlockerNode } from '../model'
import { BlockerDefs } from './BlockerDefs'
import { BlockerView } from './BlockerView'
import { StoryGraph } from './storySupport/StoryGraph'

const meta = { title: 'Canvas/Cards and edges/BlockerView' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const blockerNode: BlockerNode = {
  id: 'blocker:story',
  type: 'blocker',
  position: { x: 0, y: 0 },
  width: BLOCKER_WIDTH,
  height: BLOCKER_HEIGHT,
  data: { kind: 'blocker', taskId: 'story' },
}

export const Default: Story = {
  render: () => (
    <>
      <BlockerDefs />
      <StoryGraph nodes={[blockerNode]} nodeTypes={{ blocker: BlockerView }} />
    </>
  ),
}
