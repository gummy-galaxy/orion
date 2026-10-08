import type { Meta, StoryObj } from '@storybook/react-vite'
import { Lock } from './Lock'

const meta = { title: 'Interface/Chrome/Lock' } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <span className="st">
      <Lock /> Blocked
    </span>
  ),
}
