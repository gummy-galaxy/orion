import type { Meta, StoryObj } from '@storybook/react-vite'
import { EmptyCanvas } from './EmptyCanvas'

const meta = { title: 'Interface/Chrome/EmptyCanvas' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => <EmptyCanvas addNote={() => {}} />,
}
