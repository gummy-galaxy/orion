import type { Meta, StoryObj } from '@storybook/react-vite'
import { TaskView } from './TaskView'
import { StoryGraph } from './storySupport/StoryGraph'
import { COMPONENT_SHAPES, SHAPE_LABEL, TINTS, type SourceRef, type TaskNode } from '../model'
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
  data: {
    kind: 'task',
    type: 'component',
    label: SHAPE_LABEL[shape],
    status: 'todo',
    shape,
    color: TINTS[i],
    note: `A ${shape} component`,
  },
}))

/** Every component shape, each in its own tint. */
export const ComponentShapes: Story = { render: () => <StoryGraph nodes={shapes} nodeTypes={{ task: TaskView }} /> }

const OPEN_PULL: Partial<SourceRef> = {
  stateLabel: 'Open on GitHub',
  author: 'vocksel',
  isMine: true,
  updatedAt: '2026-10-08T12:00:00Z',
  additions: 120,
  deletions: 30,
  checkedAt: '2026-10-08T12:00:00Z',
  head: 'abc123',
}
const READINESS: [string, Partial<SourceRef>][] = [
  ['Merge conflicts', { readiness: 'conflict', checks: { state: 'passing' } }],
  ['Checks failing', { readiness: 'failing', checks: { state: 'failing' } }],
  [
    'Checks running',
    { readiness: 'running', checks: { state: 'pending', progress: 'running', total: 8, finished: 5, failed: 0 } },
  ],
  ['Checks queued', { readiness: 'waiting', checks: { state: 'pending', progress: 'waiting' } }],
  ['Checks passing, awaiting review', { readiness: 'passing', checks: { state: 'passing' } }],
  ['Ready to merge', { readiness: 'mergeable', checks: { state: 'passing' }, stateLabel: 'Approved on GitHub' }],
]
const readinessCards: TaskNode[] = READINESS.map(([label, facts], index) => ({
  ...task,
  id: `pull-${index}`,
  position: { x: (index % 3) * 260, y: Math.floor(index / 3) * 120 },
  data: {
    ...task.data,
    label,
    status: 'review',
    refs: [{ ...task.data.refs![0], key: `vocksel/orion#${127 + index}`, ...OPEN_PULL, ...facts }],
  },
}))

const severalRefs: TaskNode = {
  ...task,
  id: 'several-refs',
  position: { x: 0, y: 0 },
  data: {
    ...task.data,
    label: 'Plan the badge work',
    status: 'review',
    refs: [
      { source: 'github', kind: 'pull', key: 'vocksel/orion#127', url: 'https://github.com/vocksel/orion/pull/127' },
      { source: 'github', kind: 'issue', key: 'vocksel/orion#187', url: 'https://github.com/vocksel/orion/issues/187' },
      { source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' },
    ],
  },
}

export const SeveralRefs: Story = { render: () => <StoryGraph nodes={[severalRefs]} nodeTypes={{ task: TaskView }} /> }

export const PullReadiness: Story = {
  render: () => <StoryGraph nodes={readinessCards} nodeTypes={{ task: TaskView }} />,
}

/** Finished and waiting to be closed out: the card shimmers and shows the close-out badge. */
export const WaitingToCloseOut: Story = {
  render: () => (
    <StoryGraph
      nodes={[{ ...task, data: { ...task.data, status: 'done', celebrate: true } }]}
      nodeTypes={{ task: TaskView }}
    />
  ),
}

/** Closed out: the card carries a Done stamp. */
export const ClosedOut: Story = {
  render: () => (
    <StoryGraph nodes={[{ ...task, data: { ...task.data, status: 'done' } }]} nodeTypes={{ task: TaskView }} />
  ),
}
