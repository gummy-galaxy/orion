import type { Meta, StoryObj } from '@storybook/react-vite'
import { describeCard, type Hint, type PerchTarget } from '../companion'
import type { ViewStatus, Who } from '../model'
import { Companion } from './Companion'

const meta = { title: 'Interaction/Overlays/Companion', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const CARD_WIDTH = 150
const CARD_HEIGHT = 90
const CARDS: { id: string; status: ViewStatus; who?: Who }[] = [
  { id: 'ready', status: 'ready' },
  { id: 'yours', status: 'active', who: 'you' },
  { id: 'review', status: 'review' },
  { id: 'blocked', status: 'blocked' },
  { id: 'done', status: 'done' },
]
const TARGETS: PerchTarget[] = CARDS.map((card, i) => {
  const left = 60 + i * (CARD_WIDTH + 60)
  const top = 200

  return { id: card.id, rect: { left, top, right: left + CARD_WIDTH, bottom: top + CARD_HEIGHT } }
})

const describe = (id: string): Hint | null => {
  const card = CARDS.find((other) => other.id === id)

  return card ? describeCard(card.status, card.who) : null
}

/** Move the pointer between the cards to see each mood; leave it still for 15 seconds and it dozes off. */
export const Default: Story = {
  render: () => (
    <div style={{ position: 'relative', width: 1140, height: 480, margin: '40px auto', border: '1px solid var(--line)' }}>
      {TARGETS.map((target, i) => (
        <div
          key={target.id}
          style={{
            position: 'absolute',
            left: target.rect.left,
            top: target.rect.top,
            width: CARD_WIDTH,
            height: CARD_HEIGHT,
            borderRadius: 'var(--radius-md)',
            background: 'var(--surface)',
            border: '1px solid var(--line)',
            padding: 12,
            font: '600 13px var(--font-ui)',
            color: 'var(--ink)',
          }}
        >
          {describeCard(CARDS[i].status, CARDS[i].who).text}
        </div>
      ))}
      <Companion targets={() => TARGETS} describe={describe} />
    </div>
  ),
}
