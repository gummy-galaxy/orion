import type { Meta, StoryObj } from '@storybook/react-vite'
import { STATUS_LABEL, type ViewStatus } from '../model'
import { ChecksIcon } from './ChecksIcon'
import { StatusIcon } from './StatusIcon'

const meta = { title: 'Interface/Chrome/StatusIcon' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const row = { display: 'flex', alignItems: 'center', gap: 6, font: '12px var(--font-data)' } as const

export const Statuses: Story = {
  render: () => (
    <div style={{ display: 'grid', gap: 8 }}>
      {(Object.keys(STATUS_LABEL) as ViewStatus[]).map((status) => (
        <span key={status} style={row}>
          <StatusIcon status={status} />
          {STATUS_LABEL[status]}
        </span>
      ))}
    </div>
  ),
}

export const Checks: Story = {
  render: () => (
    <div style={{ display: 'grid', gap: 8 }}>
      {(['SUCCESS', 'FAILURE', 'PENDING'] as const).map((checks) => (
        <span key={checks} style={row}>
          <ChecksIcon checks={checks} />
          {checks.toLowerCase()}
        </span>
      ))}
    </div>
  ),
}
