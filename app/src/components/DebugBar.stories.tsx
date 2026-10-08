import { createRef } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { DebugBar } from './DebugBar'
import { StoryGraph } from './storySupport/StoryGraph'

const meta = { title: 'Interface/Chrome/DebugBar' } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <StoryGraph nodes={[]}>
      <DebugBar
        canvas={createRef<HTMLDivElement>()}
        motion={{ arrows: true, glow: true, pauseWhileMoving: true }}
        setMotion={() => {}}
        close={() => {}}
      />
    </StoryGraph>
  ),
}
