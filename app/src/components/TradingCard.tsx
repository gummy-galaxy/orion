import { useContext, type CSSProperties } from 'react'
import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { describeRarity } from '../rarity'
import { TradingIdentityContext } from '../skins/tradingIdentity'
import { getTradingFacts, type Motion, type Sticker } from '../skins/tradingFacts'
import { TradingSignal } from './TradingSignal'
import { TradingSignalIcon } from './TradingSignalIcon'
import { SourceBadges } from './SourceBadges'
import { MergePullRequest } from './MergePullRequest'
import { OpenInVscode } from './OpenInVscode'
import { Tooltip } from './Tooltip'
import { TradingKindIcon } from './TradingKindIcon'
import { TradingRaritySymbol } from './TradingRaritySymbol'

const STICKER_HINT: Record<Sticker, string> = {
  conflict: 'The pull request has merge conflicts',
  failing: 'Checks are failing',
  changes: 'A review asked for changes',
  stale: 'No change in a while',
  mergeable: 'Ready to merge',
}

const KIND_HINT: Record<CardView['kind'], string> = {
  step: 'Step',
  pr: 'Pull request',
  placeholder: 'Expected pull request',
  gate: 'Gate',
  note: 'Note',
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
  const { identity, sealSide } = useContext(TradingIdentityContext)

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
      className={`trading-frame trading-${view.status}${view.kind === 'placeholder' ? ' trading-expected' : ''}${view.kind === 'gate' ? ' trading-gate' : ''}${facts.foil ? ` trading-foil-${facts.foil}` : ''}`}
      data-hue={facts.hue}
      data-kind={view.kind}
      data-identity={identity}
      data-seal={sealSide}
      style={{ '--emblem-shift': facts.shift } as CSSProperties}
    >
      <div className="trading-art" aria-hidden="true">
        <div className="trading-emblem" />
        {facts.foil === 'holo' && <div className="trading-holo" />}
      </div>
      <div className="trading-facts">
        {facts.priority !== undefined && <FactChip text={`P${facts.priority}`} name="Priority" severity={PRIORITY_SEVERITY[facts.priority]} />}
        {facts.size && <FactChip text={facts.size} name="Size" severity={SIZE_SEVERITY[facts.size]} />}
      </div>
      {facts.sticker === 'mergeable' && view.merge ? (
        <Tooltip label="Ready to merge. Click twice to merge it.">
          <span className="trading-sticker trading-sticker-mergeable trading-merge">
            <MergePullRequest url={view.merge.url} head={view.merge.head} idleLabel="mergeable" nativeTitle={false} />
          </span>
        </Tooltip>
      ) : (
        facts.sticker && (
          <TradingSignal
            signal={facts.sticker}
            className={`trading-sticker trading-sticker-${facts.sticker}`}
            hint={STICKER_HINT[facts.sticker]}
            url={view.pullRequestUrl}
          >
            <TradingSignalIcon signal={facts.sticker} />
            <span className="trading-sticker-word">{facts.sticker}</span>
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
      <div className={`trading-tile${facts.locked ? ' trading-tile-locked' : ''}`}>
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
        <div className="trading-caption">
          <Tooltip label={KIND_HINT[view.kind]}>
            <span className="trading-kind-mark">
              <TradingKindIcon kind={view.kind} />
            </span>
          </Tooltip>
          {view.rarity && (
            <Tooltip label={describeRarity(view.rarity, view.upstream)}>
              <span className={`trading-seal trading-seal-${view.rarity}`}>
                <TradingRaritySymbol rarity={view.rarity} upstream={view.upstream} />
              </span>
            </Tooltip>
          )}
        </div>
        <Tooltip label={view.title}>
          <h3 className="trading-title">{view.title}</h3>
        </Tooltip>
        <div className="trading-bottom">
          <Tooltip label={`${facts.blockers} open ${facts.blockers === 1 ? 'blocker' : 'blockers'}`}>
            <span className="trading-blockers">{facts.blockers}</span>
          </Tooltip>
          {facts.motion && (
            <TradingSignal
              signal={facts.motion}
              className={`trading-motion trading-motion-${facts.motion}`}
              hint={MOTION_HINT[facts.motion]}
              url={view.pullRequestUrl}
            >
              <TradingSignalIcon signal={facts.motion} />
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
