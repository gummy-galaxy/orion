import type { Meta, StoryObj } from '@storybook/react-vite'
import { TaskView } from './TaskView'
import { StoryGraph } from './storySupport/StoryGraph'
import { COMPONENT_SHAPES, SHAPE_LABEL, TINTS, type TaskNode } from '../model'
import { component, note, task } from './storySupport/data'

const meta = { title: 'Canvas/Cards and edges/TaskView' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Task: Story = { render: () => <StoryGraph nodes={[task]} nodeTypes={{ task: TaskView }} /> }
export const Note: Story = { render: () => <StoryGraph nodes={[note]} nodeTypes={{ task: TaskView }} /> }
export const Component: Story = { render: () => <StoryGraph nodes={[component]} nodeTypes={{ task: TaskView }} /> }

const shapes: TaskNode[] = COMPONENT_SHAPES.map((shape, i) => ({
  id: shape,
  type: 'task',
  position: { x: (i % 4) * 260, y: Math.floor(i / 4) * 150 },
  data: { kind: 'task', itemKind: 'component', label: SHAPE_LABEL[shape], status: 'todo', shape, color: TINTS[i], note: `A ${shape} component` },
}))

/** Every component shape, each in its own tint. */
export const ComponentShapes: Story = { render: () => <StoryGraph nodes={shapes} nodeTypes={{ task: TaskView }} /> }
