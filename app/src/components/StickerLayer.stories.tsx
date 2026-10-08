import type { Meta, StoryObj } from '@storybook/react-vite'
import { StickerLayer } from './StickerLayer'
import { TaskView } from './TaskView'
import { StoryGraph } from './storySupport/StoryGraph'
import { task } from './storySupport/data'

const meta = { title: 'Canvas/Cards and edges/StickerLayer' } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <StoryGraph nodes={[task]} nodeTypes={{ task: TaskView }}>
      <StickerLayer
        stickers={[{ id: 'sticker', kind: '⭐', x: 195, y: 138, tilt: -12, fresh: false }]}
        bounds={[]}
        interactive
        settle={() => {}}
        menu={() => {}}
      />
    </StoryGraph>
  ),
}
