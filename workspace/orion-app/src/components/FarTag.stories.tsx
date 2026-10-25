import type { Meta, StoryObj } from '@storybook/react-vite'
import { FarTag } from './FarTag'

const meta = { title: 'Interface/Chrome/FarTag' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <FarTag className="card st-active">
      <span className="label">Make the canvas welcoming</span>
    </FarTag>
  ),
}
