import type { Meta, StoryObj } from '@storybook/react-vite'
import { ClusterView } from '../ClusterView'
import { CurveEdge } from '../CurveEdge'
import { GhostView } from '../GhostView'
import { StickerLayer } from '../StickerLayer'
import { TaskView } from '../TaskView'
import { StoryGraph } from './StoryGraph'
import { blocker, ghost, group, note, task } from './data'

const meta = { title: 'Canvas/Cards and edges', parameters: { layout: 'centered' } } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Task: Story = {
  name: 'TaskView',
  render: () => <StoryGraph nodes={[task]} nodeTypes={{ task: TaskView }} />,
}

export const Note: Story = {
  name: 'TaskView · note',
  render: () => <StoryGraph nodes={[note]} nodeTypes={{ task: TaskView }} />,
}

export const Ghost: Story = {
  name: 'GhostView',
  render: () => <StoryGraph nodes={[ghost]} nodeTypes={{ ghost: GhostView }} />,
}

export const Cluster: Story = {
  name: 'ClusterView',
  render: () => <StoryGraph nodes={[group]} nodeTypes={{ cluster: ClusterView }} />,
}

export const Edge: Story = {
  name: 'CurveEdge',
  render: () => (
    <StoryGraph
      nodes={[task, blocker]}
      edges={[{ id: 'task-blocker', source: task.id, target: blocker.id, type: 'curve' }]}
      nodeTypes={{ task: TaskView }}
      edgeTypes={{ curve: CurveEdge }}
    />
  ),
}

export const Stickers: Story = {
  name: 'StickerLayer',
  render: () => (
    <StoryGraph nodes={[task]} nodeTypes={{ task: TaskView }}>
      <StickerLayer
        stickers={[{ id: 'sticker', kind: '⭐', x: 195, y: 138, tilt: -12, fresh: false }]}
        bounds={[]}
        interactive
        settle={() => {}}
        menu={() => {}}
      />
    </StoryGraph>
  ),
}
