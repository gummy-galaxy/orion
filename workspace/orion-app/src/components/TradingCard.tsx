import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { getCheckCountsLabel } from '../model'
import { getTradingFacts, type Motion, type StatusBadge } from '../skins/tradingFacts'
import { TradingSignal } from './TradingSignal'
import { TradingSignalIcon } from './TradingSignalIcon'
import { SourceBadges } from './SourceBadges'
import { MergePullRequest } from './MergePullRequest'
import { OpenInVscode } from './OpenInVscode'
import { Tooltip } from './Tooltip'
import { TradingKindIcon } from './TradingKindIcon'

const STATUS_BADGE_HINT: Record<StatusBadge, string> = {
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
  if (view.layout === 'note') {
    return (
      <div className="trading-frame trading-note">
        <div className="trading-note-text">{view.title || 'Empty note'}</div>
        <SourceBadges sources={view.sources} />
      </div>
    )
  }

  const facts = getTradingFacts(view)
  const checkCounts = facts.motion ? view.checkCounts : undefined
  const checkCountsLabel = checkCounts && getCheckCountsLabel(checkCounts)

  return (
    <div
      className={
        `trading-frame trading-${view.status}${view.kind === 'placeholder' ? ' trading-expected' : ''}` +
        `${view.kind === 'gate' ? ' trading-gate' : ''}`
      }
      data-hue={facts.hue}
    >
      <div className="trading-art" aria-hidden="true" />
      <div className="trading-facts">
        {facts.priority !== undefined && (
          <FactChip text={`P${facts.priority}`} name="Priority" severity={PRIORITY_SEVERITY[facts.priority]} />
        )}
        {facts.size && <FactChip text={facts.size} name="Size" severity={SIZE_SEVERITY[facts.size]} />}
        {view.badges.map((badge) => (
          <span key={badge} className="trading-fact trading-fact-type">
            {badge}
          </span>
        ))}
      </div>
      {facts.statusBadge === 'mergeable' && view.merge ? (
        <Tooltip label="Ready to merge. Click twice to merge it.">
          <span className="trading-status-badge trading-status-badge-mergeable trading-merge">
            <MergePullRequest url={view.merge.url} head={view.merge.head} idleLabel="mergeable" nativeTitle={false} />
          </span>
        </Tooltip>
      ) : (
        facts.statusBadge && (
          <TradingSignal
            signal={facts.statusBadge}
            className={`trading-status-badge trading-status-badge-${facts.statusBadge}`}
            hint={STATUS_BADGE_HINT[facts.statusBadge]}
            url={view.pullRequestUrl}
          >
            <TradingSignalIcon signal={facts.statusBadge} />
            <span className="trading-status-badge-word">{facts.statusBadge}</span>
          </TradingSignal>
        )
      )}
      {view.pullRequestUrl && (
        <Tooltip label="Open in VS Code">
          <span className="trading-actions">
            <OpenInVscode url={view.pullRequestUrl} nativeTitle={false} />
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
        {view.fields.length > 0 && (
          <p className="trading-fields">
            {view.fields.map((field) => (
              <Tooltip key={field.name} label={`${field.label}: ${field.text}`}>
                <span className="trading-field">{field.text}</span>
              </Tooltip>
            ))}
          </p>
        )}
        <div className="trading-bottom">
          <Tooltip label={`${facts.blockers} open ${facts.blockers === 1 ? 'blocker' : 'blockers'}`}>
            <span className="trading-blockers">{facts.blockers}</span>
          </Tooltip>
          {facts.motion && (
            <TradingSignal
              signal={facts.motion}
              className={`trading-motion trading-motion-${facts.motion}${checkCounts ? ' trading-motion-counted' : ''}`}
              hint={checkCountsLabel ? `${MOTION_HINT[facts.motion]}: ${checkCountsLabel}` : MOTION_HINT[facts.motion]}
              url={view.pullRequestUrl}
            >
              <TradingSignalIcon signal={facts.motion} />
              {checkCounts && (
                <span className="trading-motion-count">
                  {checkCounts.finished}/{checkCounts.total}
                </span>
              )}
            </TradingSignal>
          )}
          <Tooltip label={`Unblocks ${facts.unblocks}`}>
            <span className="trading-unblocks">{facts.unblocks}</span>
          </Tooltip>
        </div>
      </div>
    </div>
  )
}
