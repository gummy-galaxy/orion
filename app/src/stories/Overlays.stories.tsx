import type { Meta, StoryObj } from '@storybook/react-vite'
import { AttentionOverlay } from '../attention'
import { ContextMenu } from '../ContextMenu'
import { FocusView } from '../focus'
import { Palette } from '../Palette'
import { SourceMenu } from '../SourceMenu'
import { StickerWheel } from '../StickerWheel'
import { loadoutOf } from '../sticker'
import { group, source, task } from './data'

const meta = { title: 'Interaction/Overlays', parameters: { layout: 'fullscreen' } } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Attention: Story = {
  name: 'AttentionOverlay',
  render: () => (
    <div style={{ position: 'relative', width: 800, height: 500, margin: '40px auto', border: '1px solid var(--line)' }}>
      <AttentionOverlay
        targets={[
          { id: 'near', jump: 'near', label: 'Review a pull request', count: 1, rect: { x: 470, y: 180, width: 170, height: 80 } },
          { id: 'far', jump: 'far', label: 'Find another card', count: 2, rect: { x: 950, y: 300, width: 170, height: 80 } },
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

export const Menu: Story = {
  name: 'ContextMenu',
  render: () => (
    <ContextMenu
      x={120}
      y={120}
      close={() => {}}
      items={[{ label: 'Open', hint: '↵', run: () => {} }, 'divider', { label: 'Delete', danger: true, run: () => {} }]}
    />
  ),
}

export const Focus: Story = {
  name: 'FocusView',
  render: () => (
    <div style={{ width: '100vw', height: '100vh', position: 'relative' }}>
      <div className="card st-active" style={{ position: 'absolute', left: 500, top: 300, width: 216, height: 72, padding: 12 }}>
        <span className="meta-tag">orion</span>
        <div className="label">Make the canvas welcoming</div>
      </div>
      <FocusView
        label="Make the canvas welcoming"
        card={{ x: 500, y: 300, width: 216, height: 72 }}
        sideWidth={250}
        inset={20}
        incoming={[{ id: 'first', label: 'Sketch the layout', tag: 'step', status: 'done', where: 'Canvas', related: false, flow: 'live' }]}
        outgoing={[{ id: 'next', label: 'Review the design', tag: 'step', status: 'ready', where: 'Canvas', related: false, flow: 'live' }]}
        onFocus={() => {}}
        onExit={() => {}}
      >
        <p className="facts">The focused card's details appear here.</p>
      </FocusView>
    </div>
  ),
}

export const CommandPalette: Story = {
  name: 'Palette',
  render: () => (
    <Palette
      nodes={[group, task]}
      commands={[{ id: 'new-note', label: 'New note', detail: 'Canvas', run: () => {} }]}
      jumpTo={() => {}}
      open={() => {}}
      close={() => {}}
    />
  ),
}

export const Sources: Story = {
  name: 'SourceMenu',
  render: () => (
    <div style={{ padding: 80 }}>
      <SourceMenu domain="github.com" sources={[source]} />
    </div>
  ),
}

export const Stickers: Story = {
  name: 'StickerWheel',
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
