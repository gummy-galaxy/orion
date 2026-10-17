import { useState } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { ComponentInspector } from './ComponentInspector'
import { buildWork, toServerFacts } from '../derive'
import type { AppNode, Link, TaskData } from '../model'
import { component, componentLink, store } from './storySupport/data'

const meta = { title: 'Details/Inspectors/ComponentInspector' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

function ComponentDemo() {
  const [node, setNode] = useState(component)
  const [links, setLinks] = useState<Link[]>([componentLink])
  const map = new Map<string, AppNode>([node, store].map((item) => [item.id, item]))

  return (
    <div className="panel" style={{ width: 420, padding: 20 }}>
      <ComponentInspector
        node={node}
        focus={false}
        doneEditing={() => {}}
        work={buildWork(toServerFacts(null), [node, store], links)}
        map={map}
        update={(_id, patch) => setNode({ ...node, data: { ...node.data, ...patch } as TaskData })}
        remove={() => {}}
        jumpTo={() => {}}
        links={links}
        addLink={(from, to, kind) => setLinks([...links, { id: `${from}>${to}`, from, to, kind }])}
        removeLink={(id) => setLinks(links.filter((link) => link.id !== id))}
        flipLink={(id) => setLinks(links.map((link) => (link.id === id ? { ...link, kind: link.kind === 'blocks' ? 'related' : 'blocks' } : link)))}
      />
    </div>
  )
}

export const Default: Story = { render: () => <ComponentDemo /> }
