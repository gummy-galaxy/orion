import type { Meta, StoryObj } from '@storybook/react-vite'
import { ClusterView } from './ClusterView'
import { TaskView } from './TaskView'
import { StoryGraph } from './storySupport/StoryGraph'
import { group, task } from './storySupport/data'

const meta = { title: 'Canvas/Cards and edges/ClusterView' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <StoryGraph nodes={[group, { ...task, parentId: group.id, position: { x: 60, y: 120 } }]} nodeTypes={{ cluster: ClusterView, task: TaskView }} />
  ),
}
