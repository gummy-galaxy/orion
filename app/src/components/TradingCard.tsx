import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { getTradingFacts, type Motion, type Sticker } from '../skins/tradingFacts'
import { TradingSignalIcon } from './TradingSignalIcon'
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
      <span className={`trading-fact trading-fact-${severity}`}>{text}</span>
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

export function TradingCard({ view }: { view: CardView }) {
  if (view.kind === 'note') {
    return (
      <div className="trading-frame trading-note">
        <div className="trading-note-text">{view.title || 'Empty note'}</div>
        <SourceBadges sources={view.sources} />
      </div>
    )
  }

  const facts = getTradingFacts(view)

  return (
    <div
      className={`trading-frame trading-${view.status}${view.kind === 'placeholder' ? ' trading-expected' : ''}${view.kind === 'gate' ? ' trading-gate' : ''}`}
      data-hue={facts.hue}
    >
      <div className="trading-art" aria-hidden="true" />
      <div className="trading-facts">
        {facts.priority !== undefined && <FactChip text={`P${facts.priority}`} name="Priority" severity={PRIORITY_SEVERITY[facts.priority]} />}
        {facts.size && <FactChip text={facts.size} name="Size" severity={SIZE_SEVERITY[facts.size]} />}
      </div>
      {facts.sticker && (
        <Tooltip label={STICKER_HINT[facts.sticker]}>
          <span className={`trading-sticker trading-sticker-${facts.sticker}`}>
            <TradingSignalIcon signal={facts.sticker} />
            <span className="trading-sticker-word">{facts.sticker}</span>
          </span>
        </Tooltip>
      )}
      <div className="trading-tile">
        <TradingKindIcon kind={view.kind} />
        {facts.locked && (
          <Tooltip label="Blocked">
            <span className="trading-lock">
              <LockIcon />
            </span>
          </Tooltip>
        )}
      </div>
      <div className="trading-scrim">
        <Tooltip label={view.title}>
          <h3 className="trading-title">{view.title}</h3>
        </Tooltip>
        <div className="trading-bottom">
          <Tooltip label={`${facts.blockers} open ${facts.blockers === 1 ? 'blocker' : 'blockers'}`}>
            <span className="trading-blockers">{facts.blockers}</span>
          </Tooltip>
          {facts.motion && (
            <Tooltip label={MOTION_HINT[facts.motion]}>
              <span className={`trading-motion trading-motion-${facts.motion}`}>
                <TradingSignalIcon signal={facts.motion} />
              </span>
            </Tooltip>
          )}
          <Tooltip label={`Unblocks ${facts.unblocks}`}>
            <span className="trading-unblocks">{facts.unblocks}</span>
          </Tooltip>
        </div>
      </div>
    </div>
  )
}
