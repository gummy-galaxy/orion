import type { Meta, StoryObj } from '@storybook/react-vite'
import { LinkPrompt } from './LinkPrompt'

const meta = { title: 'Interaction/Overlays/LinkPrompt', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => <LinkPrompt x={120} y={120} submit={() => new Promise(() => {})} close={() => {}} />,
}

export const Failing: Story = {
  render: () => (
    <LinkPrompt
      x={120}
      y={120}
      submit={() =>
        Promise.reject(new Error('no source recognizes https://example.com/page; add its GitHub or Jira source first'))
      }
      close={() => {}}
    />
  ),
}
