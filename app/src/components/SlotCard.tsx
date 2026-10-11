import type { CardView } from '../cardView'
import { getSlotFacts, type Motion, type SlotFact, type Sticker } from '../skins/slotFacts'
import { SlotSignalIcon } from './SlotSignalIcon'
import { SourceBadges } from './SourceBadges'
import { TradingKindIcon } from './TradingKindIcon'

const STICKER_HINT: Record<Sticker, string> = {
  conflict: 'The pull request has merge conflicts',
  failing: 'Checks are failing',
  changes: 'A review asked for changes',
  stale: 'No change in a while',
  mergeable: 'Ready to merge',
}

const MOTION_HINT: Record<Motion, string> = {
  running: 'Checks are running',
  queued: 'Checks are queued',
}

function FactChip({ fact, label, name }: { fact: SlotFact<string> | undefined; label: (value: string) => string; name: string }) {
  if (!fact) return <span className="slot-fact slot-fact-unknown" title={`${name}: unknown`} />

  const text = label(fact.value)

  return (
    <span
      className={`slot-fact${fact.estimated ? ' slot-fact-estimated' : ''}`}
      title={`${name}: ${text}${fact.estimated ? ', estimated from links' : ''}`}
    >
      {text}
    </span>
  )
}

function LockIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M7.5 11V8a4.5 4.5 0 0 1 9 0v3" fill="none" stroke="currentColor" strokeWidth="2.4" />
      <rect x="5" y="11" width="14" height="10" rx="2.4" fill="currentColor" />
    </svg>
  )
}

export function SlotCard({ view }: { view: CardView }) {
  if (view.kind === 'note') {
    return (
      <div className="slot-frame slot-note">
        <div className="slot-note-text" title={view.title}>
          {view.title || 'Empty note'}
        </div>
        <SourceBadges sources={view.sources} />
      </div>
    )
  }

  const facts = getSlotFacts(view)
  const priority = facts.priority && { value: String(facts.priority.value), estimated: facts.priority.estimated }

  return (
    <div
      className={`slot-frame slot-${view.status}${view.kind === 'placeholder' ? ' slot-expected' : ''}${view.kind === 'gate' ? ' slot-gate' : ''}`}
      data-hue={facts.hue}
    >
      <div className="slot-art" aria-hidden="true" />
      <div className="slot-facts">
        <FactChip fact={priority} label={(value) => `P${value}`} name="Priority" />
        <FactChip fact={facts.size} label={(value) => value} name="Size" />
      </div>
      {facts.sticker && (
        <span className={`slot-sticker slot-sticker-${facts.sticker}`} title={STICKER_HINT[facts.sticker]}>
          <SlotSignalIcon signal={facts.sticker} />
          {facts.sticker}
        </span>
      )}
      <div className="slot-tile">
        <TradingKindIcon kind={view.kind} />
        {facts.locked && (
          <span className="slot-lock" title="Blocked">
            <LockIcon />
          </span>
        )}
      </div>
      <div className="slot-scrim">
        <h3 className="slot-title" title={view.title}>
          {view.title}
        </h3>
        <div className="slot-bottom">
          <span className="slot-blockers" title={`${facts.blockers} open ${facts.blockers === 1 ? 'blocker' : 'blockers'}`}>
            {facts.blockers}
          </span>
          {facts.motion && (
            <span className={`slot-motion slot-motion-${facts.motion}`} title={MOTION_HINT[facts.motion]}>
              <SlotSignalIcon signal={facts.motion} />
            </span>
          )}
          <span className="slot-unblocks" title={`Unblocks ${facts.unblocks}`}>
            {facts.unblocks}
          </span>
        </div>
      </div>
    </div>
  )
}
