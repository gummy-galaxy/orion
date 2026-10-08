import type { Meta, StoryObj } from '@storybook/react-vite'
import { Favicon } from './Favicon'

const meta = { title: 'Interface/Chrome/Favicon' } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = { render: () => <Favicon domain="example" /> }
