import type { Meta, StoryObj } from '@storybook/react-vite'
import { CurveEdge } from './CurveEdge'
import { TaskView } from './TaskView'
import { StoryGraph } from './storySupport/StoryGraph'
import { blocker, task } from './storySupport/data'

const meta = { title: 'Canvas/Cards and edges/CurveEdge' } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <StoryGraph
      nodes={[task, blocker]}
      edges={[{ id: 'task-blocker', source: task.id, target: blocker.id, type: 'curve' }]}
      nodeTypes={{ task: TaskView }}
      edgeTypes={{ curve: CurveEdge }}
    />
  ),
}
