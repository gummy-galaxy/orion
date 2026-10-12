import { useContext, useState, type CSSProperties, type PointerEvent } from 'react'
import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { describeRarity } from '../rarity'
import { SCENE_LOOKS, TradingIdentityContext } from '../skins/tradingIdentity'
import { getTradingFacts, KIND_HINT, MOTION_HINT, STICKER_HINT } from '../skins/tradingFacts'
import { TradingSignal } from './TradingSignal'
import { TradingSignalIcon } from './TradingSignalIcon'
import { SourceBadges } from './SourceBadges'
import { MergePullRequest } from './MergePullRequest'
import { OpenInVscode } from './OpenInVscode'
import { Tooltip } from './Tooltip'
import { TradingKindIcon } from './TradingKindIcon'
import { TradingRaritySymbol } from './TradingRaritySymbol'
import { TradingScene } from './TradingScene'
import { TradingShaderArt } from './TradingShaderArt'

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

// Foil catches the light where the pointer is. Writing the position straight to the element skips React, so
// moving over a card repaints only that card.
function trackFoil(event: PointerEvent<HTMLDivElement>) {
  const box = event.currentTarget.getBoundingClientRect()

  event.currentTarget.style.setProperty('--mx', `${((event.clientX - box.left) / box.width) * 100}%`)
  event.currentTarget.style.setProperty('--my', `${((event.clientY - box.top) / box.height) * 100}%`)
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
  const { identity, sealSide, motion = 'hover' } = useContext(TradingIdentityContext)
  const [hovered, setHovered] = useState(false)

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
      className={`trading-frame trading-${view.status}${view.kind === 'placeholder' ? ' trading-expected' : ''}${view.kind === 'gate' ? ' trading-gate' : ''}${facts.finish ? ` trading-finish-${facts.finish}` : ''}`}
      data-hue={facts.hue}
      data-kind={view.kind}
      data-identity={identity}
      data-look={SCENE_LOOKS.includes(identity) ? 'scene' : undefined}
      data-seal={sealSide}
      style={{ '--emblem-shift': facts.shift } as CSSProperties}
      onPointerMove={facts.finish === 'foil' || facts.finish === 'holo' ? trackFoil : undefined}
      onPointerEnter={() => setHovered(true)}
      onPointerLeave={() => setHovered(false)}
    >
      <div className="trading-art" aria-hidden="true">
        {(identity === 'shader' || identity === 'cosmos') && (
          <TradingShaderArt kind={view.kind} seed={view.artSeed} inks={facts.inks} motion={motion === 'always' ? 'all' : hovered ? 'top' : 'still'} />
        )}
        {(identity === 'scene' || identity === 'cosmos') && <TradingScene kind={view.kind} seed={facts.seed} subjectOnly={identity === 'cosmos'} />}
        {!SCENE_LOOKS.includes(identity) && <div className="trading-emblem" />}
        {facts.finish === 'holo' && <div className="trading-holo" />}
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
            <Tooltip label={describeRarity(view.rarity, view.upstream, view.priority)}>
              <span className={`trading-seal trading-seal-${view.rarity}`}>
                <TradingRaritySymbol rarity={view.rarity} upstream={view.upstream} priority={view.priority} />
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
