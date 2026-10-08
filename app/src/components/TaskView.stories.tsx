import type { Meta, StoryObj } from '@storybook/react-vite'
import { TaskView } from './TaskView'
import { StoryGraph } from './storySupport/StoryGraph'
import { note, task } from './storySupport/data'

const meta = { title: 'Canvas/Cards and edges/TaskView' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Task: Story = { render: () => <StoryGraph nodes={[task]} nodeTypes={{ task: TaskView }} /> }
export const Note: Story = { render: () => <StoryGraph nodes={[note]} nodeTypes={{ task: TaskView }} /> }
