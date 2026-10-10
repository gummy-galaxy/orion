import { useState } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { TaskInspector } from './TaskInspector'
import { deriveWork } from '../derive'
import { blocker, links, nodeMap, task } from './storySupport/data'

const meta = { title: 'Details/Inspectors/TaskInspector' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

function TaskDemo() {
  const [node, setNode] = useState(task)
  const currentWork = deriveWork([node, blocker], links)
  const currentMap = new Map(nodeMap).set(node.id, node)

  return (
    <div className="panel" style={{ width: 420, padding: 20 }}>
      <TaskInspector
        node={node}
        work={currentWork}
        map={currentMap}
        github={null}
        update={(_id, patch) => setNode({ ...node, data: { ...node.data, ...patch } })}
        jumpTo={() => {}}
        links={links}
        addLink={() => {}}
        removeLink={() => {}}
        flipLink={() => {}}
      />
    </div>
  )
}

export const Default: Story = { render: () => <TaskDemo /> }
