import type { Meta, StoryObj } from '@storybook/react-vite'
import { useState } from 'react'
import { LayoutModeToggle, type LayoutMode } from './LayoutModeToggle'

const meta = { title: 'Interface/Chrome/LayoutModeToggle' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

function Interactive() {
  const [mode, setMode] = useState<LayoutMode>('layered')

  return <LayoutModeToggle mode={mode} onChange={setMode} />
}

export const Default: Story = { render: () => <Interactive /> }
