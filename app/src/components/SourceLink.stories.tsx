import type { Meta, StoryObj } from '@storybook/react-vite'
import { SourceLink } from './SourceLink'
import { source } from './storySupport/data'

const meta = { title: 'Interface/Chrome/SourceLink' } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = { render: () => <SourceLink source={source}>Open vocksel/orion ↗</SourceLink> }
