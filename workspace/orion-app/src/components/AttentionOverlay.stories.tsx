import type { Meta, StoryObj } from '@storybook/react-vite'
import { AttentionOverlay } from './AttentionOverlay'

const meta = { title: 'Interaction/Overlays/AttentionOverlay', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <div
      style={{
        position: 'relative',
        width: 800,
        height: 500,
        margin: '40px auto',
        border: '1px solid var(--border-default)',
      }}
    >
      <AttentionOverlay
        targets={[
          {
            id: 'near',
            jump: 'near',
            label: 'Review a pull request',
            count: 1,
            rect: { x: 470, y: 180, width: 170, height: 80 },
          },
          {
            id: 'far',
            jump: 'far',
            label: 'Find another card',
            count: 2,
            rect: { x: 950, y: 300, width: 170, height: 80 },
          },
        ]}
        count={3}
        elsewhere={1}
        cursor={{ x: 260, y: 220 }}
        width={800}
        height={500}
        onJump={() => {}}
      />
    </div>
  ),
}
