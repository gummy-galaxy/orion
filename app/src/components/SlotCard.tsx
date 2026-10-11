import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { getSlotFacts, type Motion, type Sticker } from '../skins/slotFacts'
import { SlotSignalIcon } from './SlotSignalIcon'
import { SourceBadges } from './SourceBadges'
import { Tooltip } from './Tooltip'
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

type Severity = 'critical' | 'high' | 'medium' | 'low'

const PRIORITY_SEVERITY: Record<Priority, Severity> = { 0: 'critical', 1: 'high', 2: 'medium', 3: 'low' }
const SIZE_SEVERITY: Record<CardSizeLabel, Severity> = { XL: 'critical', L: 'high', M: 'medium', S: 'low' }

function FactChip({ text, name, severity }: { text: string; name: string; severity: Severity }) {
  return (
    <Tooltip label={`${name} ${text}`}>
      <span className={`slot-fact slot-fact-${severity}`}>{text}</span>
    </Tooltip>
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
        <div className="slot-note-text">{view.title || 'Empty note'}</div>
        <SourceBadges sources={view.sources} />
      </div>
    )
  }

  const facts = getSlotFacts(view)

  return (
    <div
      className={`slot-frame slot-${view.status}${view.kind === 'placeholder' ? ' slot-expected' : ''}${view.kind === 'gate' ? ' slot-gate' : ''}`}
      data-hue={facts.hue}
    >
      <div className="slot-art" aria-hidden="true" />
      <div className="slot-facts">
        {facts.priority !== undefined && <FactChip text={`P${facts.priority}`} name="Priority" severity={PRIORITY_SEVERITY[facts.priority]} />}
        {facts.size && <FactChip text={facts.size} name="Size" severity={SIZE_SEVERITY[facts.size]} />}
      </div>
      {facts.sticker && (
        <Tooltip label={STICKER_HINT[facts.sticker]}>
          <span className={`slot-sticker slot-sticker-${facts.sticker}`}>
            <SlotSignalIcon signal={facts.sticker} />
            {facts.sticker}
          </span>
        </Tooltip>
      )}
      <div className="slot-tile">
        <TradingKindIcon kind={view.kind} />
        {facts.locked && (
          <Tooltip label="Blocked">
            <span className="slot-lock">
              <LockIcon />
            </span>
          </Tooltip>
        )}
      </div>
      <div className="slot-scrim">
        <Tooltip label={view.title}>
          <h3 className="slot-title">{view.title}</h3>
        </Tooltip>
        <div className="slot-bottom">
          <Tooltip label={`${facts.blockers} open ${facts.blockers === 1 ? 'blocker' : 'blockers'}`}>
            <span className="slot-blockers">{facts.blockers}</span>
          </Tooltip>
          {facts.motion && (
            <Tooltip label={MOTION_HINT[facts.motion]}>
              <span className={`slot-motion slot-motion-${facts.motion}`}>
                <SlotSignalIcon signal={facts.motion} />
              </span>
            </Tooltip>
          )}
          <Tooltip label={`Unblocks ${facts.unblocks}`}>
            <span className="slot-unblocks">{facts.unblocks}</span>
          </Tooltip>
        </div>
      </div>
    </div>
  )
}
