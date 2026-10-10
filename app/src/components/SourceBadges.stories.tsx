import type { Meta, StoryObj } from '@storybook/react-vite'
import { SourceBadges } from './SourceBadges'
import { source } from './storySupport/data'

const meta = { title: 'Interface/Chrome/SourceBadges' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = { render: () => <SourceBadges sources={[source, { ...source, label: 'vocksel/other' }]} /> }

const many = (domain: string, count: number) => Array.from({ length: count }, (_, index) => ({ domain, label: `${domain} ${index + 1}` }))

export const SeveralSources: Story = {
  render: () => (
    <div className="cluster" style={{ position: 'relative', width: 280, height: 80 }}>
      <SourceBadges sources={[...many('github.com', 12), ...many('roblox.atlassian.net', 4), ...many('hop', 3), ...many('figma.com', 2)]} />
    </div>
  ),
}
