import type { Meta, StoryObj } from '@storybook/react-vite'
import { TaskView } from './TaskView'
import { StoryGraph } from './storySupport/StoryGraph'
import type { PullDetails, TaskNode } from '../model'
import { note, task } from './storySupport/data'

const meta = { title: 'Canvas/Cards and edges/TaskView' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Task: Story = { render: () => <StoryGraph nodes={[task]} nodeTypes={{ task: TaskView }} /> }
export const Note: Story = { render: () => <StoryGraph nodes={[note]} nodeTypes={{ task: TaskView }} /> }

const OPEN_PULL: PullDetails = {
  state: 'OPEN',
  draft: false,
  title: 'Make the canvas welcoming',
  author: 'vocksel',
  mine: true,
  requestedFromYou: false,
  updatedAt: '2026-10-08T12:00:00Z',
  additions: 120,
  deletions: 30,
  checkedAt: '2026-10-08T12:00:00Z',
  head: 'abc123',
}
const READINESS: [string, Partial<PullDetails>][] = [
  ['Merge conflicts', { checks: 'SUCCESS', mergeable: 'CONFLICTING', mergeState: 'DIRTY' }],
  ['Checks failing', { checks: 'FAILURE', mergeState: 'BLOCKED' }],
  ['Checks running', { checks: 'PENDING', checkProgress: 'running' }],
  ['Checks queued', { checks: 'PENDING', checkProgress: 'waiting' }],
  ['Checks passing, awaiting review', { checks: 'SUCCESS', mergeable: 'MERGEABLE', mergeState: 'BLOCKED' }],
  ['Ready to merge', { checks: 'SUCCESS', mergeable: 'MERGEABLE', mergeState: 'CLEAN', reviewDecision: 'APPROVED' }],
]
const readinessCards: TaskNode[] = READINESS.map(([label, details], index) => ({
  ...task,
  id: `pull-${index}`,
  position: { x: (index % 3) * 260, y: Math.floor(index / 3) * 120 },
  data: {
    ...task.data,
    label,
    status: 'review',
    refs: [{ ...task.data.refs![0], key: `vocksel/orion#${127 + index}`, details: { ...OPEN_PULL, ...details } }],
  },
}))

export const PullReadiness: Story = { render: () => <StoryGraph nodes={readinessCards} nodeTypes={{ task: TaskView }} /> }
