import type { Meta, StoryObj } from '@storybook/react-vite'
import { Ring } from './Ring'

const meta = { title: 'Interface/Chrome/Ring' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = { render: () => <Ring done={3} total={8} size={48} /> }
