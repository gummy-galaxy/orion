import type { Meta, StoryObj } from '@storybook/react-vite'
import { CurveEdge } from './CurveEdge'
import { TaskView } from './TaskView'
import { StoryGraph } from './storySupport/StoryGraph'
import { blocker, component, componentLink, store, task } from './storySupport/data'

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

/** A link between components draws still, with its label on the line. */
export const Labeled: Story = {
  render: () => (
    <StoryGraph
      nodes={[component, store]}
      edges={[
        {
          id: componentLink.id,
          source: component.id,
          target: store.id,
          type: 'curve',
          className: 'e-still',
          label: componentLink.label,
          labelBgPadding: [6, 3],
          labelBgBorderRadius: 4,
        },
      ]}
      nodeTypes={{ task: TaskView }}
      edgeTypes={{ curve: CurveEdge }}
    />
  ),
}
