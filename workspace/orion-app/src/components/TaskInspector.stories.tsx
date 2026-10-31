import { useState } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { TaskInspector } from './TaskInspector'
import builtinTypes from '../cardTypes/builtinTypes.json'
import { FIGMA_FRAME } from '../cardTypes/fixtures/figmaFrame'
import { registerCardTypes } from '../cardTypes/registerCardTypes'
import { buildWork, toServerFacts } from '../derive'
import { blocker, derived, links, nodeMap, task } from './storySupport/data'

const meta = { title: 'Details/Inspectors/TaskInspector' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

// A source's type, registered as the server would send it.
registerCardTypes([...builtinTypes, FIGMA_FRAME])

function TaskDemo({ initial = task }: { initial?: typeof task }) {
  const [node, setNode] = useState(initial)
  const currentWork = buildWork(toServerFacts(derived), [node, blocker], links)
  const currentMap = new Map(nodeMap).set(node.id, node)

  return (
    <div className="panel" style={{ width: 420, padding: 20 }}>
      <TaskInspector
        node={node}
        work={currentWork}
        map={currentMap}
        github={null}
        update={(_id, patch) => setNode({ ...node, data: { ...node.data, ...patch } })}
        saveFields={() => Promise.resolve(null)}
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

/** A type that declares its own states: the status list offers them, and the one that means done finishes the card. */
export const DeclaredStates: Story = {
  name: 'A type with its own states',
  render: () => <TaskDemo initial={{ ...task, data: { ...task.data, type: 'figma.frame', status: 'drafting' } }} />,
}
