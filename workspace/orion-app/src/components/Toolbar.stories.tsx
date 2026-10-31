import type { Meta, StoryObj } from '@storybook/react-vite'
import { DEFAULT_KEYBINDINGS } from '../keybindings'
import { Toolbar } from './Toolbar'

const meta = { title: 'Interface/Chrome/Toolbar' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => <Toolbar tool="select" sticker="🎉" keybindings={DEFAULT_KEYBINDINGS} setTool={() => {}} />,
}
