import type { Meta, StoryObj } from '@storybook/react-vite'
import { GroupFacts } from './GroupFacts'

const meta = { title: 'Details/Inspectors/GroupFacts' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <div className="panel" style={{ width: 420, padding: 20 }}>
      <GroupFacts stats={{ total: 8, done: 3, ready: 2, blocked: 3, outside: 1 }} />
    </div>
  ),
}
