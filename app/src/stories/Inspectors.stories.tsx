import { useState } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { GroupArrange } from '../GroupArrange'
import { GroupFacts } from '../GroupFacts'
import { LinkList } from '../LinkList'
import { NoteInspector } from '../NoteInspector'
import { TaskInspector } from '../TaskInspector'
import { deriveWork } from '../derive'
import type { TaskData } from '../model'
import { blocker, group, links, nodeMap, note, task, work } from './data'

const meta = { title: 'Details/Inspectors' } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

const frame = (content: React.ReactNode) => (
  <div className="panel" style={{ width: 420, padding: 20 }}>
    {content}
  </div>
)

export const GroupProgress: Story = {
  name: 'GroupFacts',
  render: () => frame(<GroupFacts stats={{ total: 8, done: 3, ready: 2, blocked: 3, outside: 1 }} />),
}

function ArrangeDemo() {
  const [data, setData] = useState(group.data)
  return frame(<GroupArrange data={data} change={(patch) => setData({ ...data, ...patch })} />)
}

export const Arrangement: Story = { name: 'GroupArrange', render: () => <ArrangeDemo /> }

function NoteDemo() {
  const [node, setNode] = useState(note)
  return frame(
    <NoteInspector
      node={node}
      focus={false}
      doneEditing={() => {}}
      update={(_id, patch) => setNode({ ...node, data: { ...node.data, ...patch } as TaskData })}
      remove={() => setNode({ ...node, data: { ...node.data, label: 'Deleted note' } })}
    />,
  )
}

export const Note: Story = { name: 'NoteInspector', render: () => <NoteDemo /> }

function TaskDemo() {
  const [node, setNode] = useState(task)
  const currentWork = deriveWork([node, blocker], links)
  const currentMap = new Map(nodeMap).set(node.id, node)
  return frame(
    <TaskInspector
      node={node}
      work={currentWork}
      map={currentMap}
      github={null}
      githubOwner="vocksel"
      update={(_id, patch) => setNode({ ...node, data: { ...node.data, ...patch } })}
      jumpTo={() => {}}
      links={links}
      addLink={() => {}}
      removeLink={() => {}}
      flipLink={() => {}}
    />,
  )
}

export const Task: Story = { name: 'TaskInspector', render: () => <TaskDemo /> }

export const Connections: Story = {
  name: 'LinkList',
  render: () =>
    frame(
      <LinkList
        node={task}
        work={work}
        nodeMap={nodeMap}
        links={links}
        jumpTo={() => {}}
        addLink={() => {}}
        removeLink={() => {}}
        flipLink={() => {}}
      />,
    ),
}
