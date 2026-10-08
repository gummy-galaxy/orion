import type { Meta, StoryObj } from '@storybook/react-vite'
import { StickerWheel } from './StickerWheel'
import { loadoutOf } from '../sticker'

const meta = { title: 'Interaction/Overlays/StickerWheel', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <StickerWheel
      at={{ x: window.innerWidth / 2, y: window.innerHeight / 2 }}
      held={false}
      current="🎉"
      loadout={loadoutOf()}
      pick={() => {}}
      assign={() => {}}
      close={() => {}}
    />
  ),
}
