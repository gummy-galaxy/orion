import type { Meta, StoryObj } from '@storybook/react-vite'
import { WindowControls } from './WindowControls'

const meta = { title: 'Interface/Chrome/WindowControls' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <div style={{ position: 'relative', height: 120, width: 400 }}>
      <WindowControls />
    </div>
  ),
}
