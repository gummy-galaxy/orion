import { useState } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { GroupArrange } from './GroupArrange'
import { group } from './storySupport/data'

const meta = { title: 'Details/Inspectors/GroupArrange' } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

function ArrangeDemo() {
  const [data, setData] = useState(group.data)
  return (
    <div className="panel" style={{ width: 420, padding: 20 }}>
      <GroupArrange data={data} change={(patch) => setData({ ...data, ...patch })} />
    </div>
  )
}

export const Default: Story = { render: () => <ArrangeDemo /> }
