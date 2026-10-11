import type { Meta, StoryObj } from '@storybook/react-vite'
import type { Who } from '../model'
import { WhoBadge } from './WhoBadge'

const meta = { title: 'Interface/Chrome/WhoBadge' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const All: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: 12 }}>
      {(['you', 'review', 'ci'] as Who[]).map((who) => (
        <span key={who} style={{ position: 'relative', width: 15, height: 15 }}>
          <WhoBadge who={who} />
        </span>
      ))}
    </div>
  ),
}
