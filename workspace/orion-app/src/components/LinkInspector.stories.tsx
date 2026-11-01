import { useState } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { LinkInspector } from './LinkInspector'
import type { AppNode } from '../model'
import { component, componentLink, store } from './storySupport/data'

const meta = { title: 'Details/Inspectors/LinkInspector' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const map = new Map<string, AppNode>([component, store].map((node) => [node.id, node]))

function LinkDemo() {
  const [link, setLink] = useState(componentLink)

  return (
    <div className="panel" style={{ width: 420, padding: 20 }}>
      <LinkInspector
        link={link}
        map={map}
        focus={false}
        onDoneEditing={() => {}}
        update={(_id, patch) => setLink({ ...link, ...patch })}
        flip={() => setLink({ ...link, kind: link.kind === 'blocks' ? 'related' : 'blocks' })}
        remove={() => {}}
        jumpTo={() => {}}
      />
    </div>
  )
}

export const Default: Story = { render: () => <LinkDemo /> }
