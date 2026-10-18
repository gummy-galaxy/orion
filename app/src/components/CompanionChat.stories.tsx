import type { Meta, StoryObj } from '@storybook/react-vite'
import { useState } from 'react'
import type { CardView } from '../cardView'
import { describeCard, type Hint, type PerchTarget } from '../companion'
import { skinOf } from '../skins'
import type { CardSession, SessionTurn } from '../sessions/types'
import { Companion } from './Companion'
import { CompanionChat } from './CompanionChat'
import { TradingCard } from './TradingCard'

const meta = { title: 'Interaction/Overlays/CompanionChat', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const MINUTE_MS = 60 * 1000
const ago = (minutes: number) => new Date(Date.now() - minutes * MINUTE_MS).toISOString()

type Fixture = { view: CardView; turns: SessionTurn[] }

const card = (id: string, title: string, status: CardView['status'], group: string, session: CardSession): CardView => ({
  id,
  kind: 'pr',
  title,
  tag: `vocksel/orion#${id}`,
  url: null,
  status,
  statusLabel: status,
  leverage: 0,
  upstream: 0,
  sources: [],
  artSeed: id,
  blockers: 0,
  unblocks: 1,
  group,
  session,
})

const FIXTURES: Fixture[] = [
  {
    view: card('450', 'Refresh cards in view sooner', 'active', 'navigation', {
      key: 'claude:7d1e',
      title: 'Refresh cards in view sooner (#450)',
      state: 'working',
      lastMessage: 'Running `lute test` on the refresh loop now; two specs left to update for the in-view queue.',
      updatedAt: ago(1),
      isLive: true,
    }),
    turns: [
      { role: 'you', text: 'Refresh the cards in view before the rest, so what I am looking at is never the stalest.' },
      { role: 'agent', text: 'The background loop refetches by `updatedAt`. I will order each pass by distance from the viewport the app reports.' },
      { role: 'agent', text: 'Running `lute test` on the refresh loop now; two specs left to update for the in-view queue.' },
    ],
  },
  {
    view: card('468', 'Refuse cross-site HTTP API requests', 'active', 'workspaces', {
      key: 'claude:3b9a',
      title: 'Refuse cross-site HTTP API requests (#468)',
      state: 'waiting',
      lastMessage: 'I need to run `gh pr edit 468 --add-label security` to tag the PR. Allow it?',
      updatedAt: ago(14),
      isLive: true,
    }),
    turns: [
      { role: 'you', text: 'Lock down `orion serve` so another site in the browser cannot call it.' },
      { role: 'agent', text: 'Requests now need the `Origin` the app is served from, and anything else gets a 403. Tests pass.' },
      { role: 'agent', text: 'I need to run `gh pr edit 468 --add-label security` to tag the PR. Allow it?' },
    ],
  },
  {
    view: card('464', 'Fix video crop at scale 2', 'review', 'pr-queue', {
      key: 'claude:a6b8',
      title: 'Fix video crop at --scale 2 in capture.mjs',
      state: 'done',
      lastMessage: 'I opened draft PR [vocksel/orion#464](https://github.com/vocksel/orion/pull/464). Videos match the screenshots at both scales.',
      updatedAt: ago(95),
      isLive: false,
    }),
    turns: [
      { role: 'you', text: 'Videos come out cropped wrong at `--scale 2`. Fix the capture script.' },
      { role: 'agent', text: 'Chrome reports CSS pixels, and the crop used device pixels. I now scale the crop box by the real device ratio.' },
      {
        role: 'agent',
        text: 'I opened draft PR [vocksel/orion#464](https://github.com/vocksel/orion/pull/464). Videos match the screenshots at both scales.',
      },
    ],
  },
]

const SIZE = skinOf('trading').size
const GAP = 48
const LEFT = 60
const TOP = 120

const TARGETS: PerchTarget[] = FIXTURES.map((fixture, i) => {
  const left = LEFT + i * (SIZE.width + GAP)

  return { id: fixture.view.id, rect: { left, top: TOP, right: left + SIZE.width, bottom: TOP + SIZE.height } }
})

const describe = (id: string): Hint | null => {
  const fixture = FIXTURES.find((other) => other.view.id === id)

  return fixture ? describeCard(fixture.view.status === 'review' ? 'review' : 'active', 'you') : null
}

function Board({ initial }: { initial: string | null }) {
  const [selected, setSelected] = useState<string | null>(initial)
  const open = FIXTURES.find((fixture) => fixture.view.id === selected)

  return (
    <div style={{ position: 'relative', width: 1300, height: 720, margin: '24px auto', border: '1px solid var(--line)', overflow: 'hidden' }}>
      <p style={{ position: 'absolute', left: LEFT, top: 40, margin: 0, font: '600 14px var(--font-ui)', color: 'var(--muted)' }}>
        Click a card to chat with its Claude Code session.
      </p>
      {FIXTURES.map((fixture, i) => (
        <div
          key={fixture.view.id}
          role="button"
          tabIndex={0}
          aria-pressed={selected === fixture.view.id}
          onClick={() => setSelected(fixture.view.id)}
          onKeyDown={(event) => {
            if (event.key === 'Enter') setSelected(fixture.view.id)
          }}
          style={{ position: 'absolute', left: TARGETS[i].rect.left, top: TOP, ...SIZE, cursor: 'pointer' }}
        >
          <div
            className={`card skin-trading st-${fixture.view.status}${selected === fixture.view.id ? ' selected' : ''}`}
            style={{ width: '100%', height: '100%', outline: selected === fixture.view.id ? '3px solid var(--accent)' : undefined, borderRadius: 14 }}
          >
            <TradingCard view={fixture.view} />
          </div>
        </div>
      ))}
      <Companion targets={() => TARGETS} describe={describe} />
      {open?.view.session && <CompanionChat key={open.view.id} session={open.view.session} turns={open.turns} onClose={() => setSelected(null)} />}
    </div>
  )
}

/** Three cards whose branches have Claude Code sessions: one working, one waiting on a permission prompt, one done. */
export const OnCards: Story = { render: () => <Board initial="468" /> }

export const NothingSelected: Story = { render: () => <Board initial={null} /> }

/** The chat alone, while the transcript is still loading. */
export const Loading: Story = {
  render: () => (
    <div style={{ position: 'relative', width: 600, height: 620 }}>
      <CompanionChat session={FIXTURES[0].view.session!} turns={null} onClose={() => {}} />
    </div>
  ),
}
