import { useState } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { NoteInspector } from './NoteInspector'
import type { TaskData } from '../model'
import { note } from './storySupport/data'

const meta = { title: 'Details/Inspectors/NoteInspector' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

function NoteDemo() {
  const [node, setNode] = useState(note)

  return (
    <div className="panel" style={{ width: 420, padding: 20 }}>
      <NoteInspector
        node={node}
        focus={false}
        doneEditing={() => {}}
        update={(_id, patch) => setNode({ ...node, data: { ...node.data, ...patch } as TaskData })}
        saveFields={() => Promise.resolve(null)}
        remove={() => setNode({ ...node, data: { ...node.data, label: 'Deleted note' } })}
      />
    </div>
  )
}

export const Default: Story = { render: () => <NoteDemo /> }
