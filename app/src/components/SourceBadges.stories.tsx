import type { Meta, StoryObj } from '@storybook/react-vite'
import { SourceBadges } from './SourceBadges'
import { source } from './storySupport/data'

const meta = { title: 'Interface/Chrome/SourceBadges' } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = { render: () => <SourceBadges sources={[source, { ...source, label: 'vocksel/other' }]} /> }
