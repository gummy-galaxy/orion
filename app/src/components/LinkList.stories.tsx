import type { Meta, StoryObj } from '@storybook/react-vite'
import { LinkList } from './LinkList'
import { links, nodeMap, task, work } from './storySupport/data'

const meta = { title: 'Details/Inspectors/LinkList' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <div className="panel" style={{ width: 420, padding: 20 }}>
      <LinkList
        node={task}
        work={work}
        nodeMap={nodeMap}
        links={links}
        jumpTo={() => {}}
        addLink={() => {}}
        removeLink={() => {}}
        flipLink={() => {}}
      />
    </div>
  ),
}
