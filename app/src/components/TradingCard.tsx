import type { CSSProperties } from 'react'
import type { CardView } from '../cardView'
import { READINESS_LABEL } from '../model'
import { getCardInks } from '../skins/frameColor'
import { ChecksIcon } from './ChecksIcon'
import { SourceBadges } from './SourceBadges'
import { StatusIcon } from './StatusIcon'
import { TradingArtwork } from './TradingArtwork'
import { TradingKindIcon } from './TradingKindIcon'

type ArtKind = Exclude<CardView['kind'], 'note'>

const KIND_LABEL: Record<ArtKind, string> = {
  step: 'Step',
  pr: 'Pull request',
  placeholder: 'Expected PR',
  gate: 'Gate',
}

// Only work you can act on now is your move; a draft still waiting on other open work isn't yet.
function isYourMove(view: CardView): boolean {
  return view.who === 'you' && (view.status === 'ready' || view.status === 'active' || view.status === 'review')
}

export function TradingCard({ view }: { view: CardView }) {
  if (view.kind === 'note') {
    return (
      <div className="trading-frame trading-note">
        <div className="trading-note-label">Note</div>
        <div className="trading-note-text" title={view.title}>
          {view.title || 'Empty note'}
        </div>
        <SourceBadges sources={view.sources} />
      </div>
    )
  }

  const inks = getCardInks(view.repo, view.kind)
  const yourMove = isYourMove(view)
  const { readiness } = view
  const number = view.tag.match(/#(\d+)$/)?.[1]
  const repositoryName = view.repo?.split('/').at(-1)
  const style = { '--trading-ink-one': inks[0], '--trading-ink-two': inks[1] } as CSSProperties

  return (
    <div
      className={`trading-frame trading-${yourMove ? 'you' : view.status}${view.kind === 'placeholder' ? ' trading-expected' : ''}${view.kind === 'gate' ? ' trading-gate' : ''}`}
      style={style}
    >
      <i className="trading-glow" aria-hidden="true" />
      {yourMove && <span className="trading-move">Your move</span>}
      <div className="trading-frame-border">
        <div className="trading-inner">
          <header className="trading-title">
            <h3 title={view.title}>{view.title}</h3>
            {number && <span className="trading-number">#{number}</span>}
          </header>
          <TradingArtwork view={view} kind={view.kind} inks={inks} />
          <div className="trading-type">
            <TradingKindIcon kind={view.kind} />
            <span>
              {KIND_LABEL[view.kind]}
              {repositoryName && ` · ${repositoryName}`}
            </span>
            <i className="trading-gem" aria-hidden="true" />
          </div>
          <p className={`trading-text${view.note ? '' : ' trading-flavor'}`} title={view.note || view.tag}>
            {view.note || view.tag}
          </p>
          <footer className="trading-bottom">
            {view.changeSize ? (
              <>
                <span className="trading-add">+{view.changeSize.additions}</span>
                <span className="trading-del">−{view.changeSize.deletions}</span>
              </>
            ) : (
              <span>{view.kind === 'pr' || view.kind === 'placeholder' ? 'Not opened' : 'No PR'}</span>
            )}
            <span
              className="trading-state"
              title={readiness && !view.readyToMerge ? `${view.statusLabel} · ${READINESS_LABEL[readiness]}` : view.statusLabel}
            >
              {view.readyToMerge ? (
                <ChecksIcon readiness="mergeable" />
              ) : (
                <span className="status-mark">
                  <StatusIcon status={view.status} />
                  {readiness && <ChecksIcon readiness={readiness} title={READINESS_LABEL[readiness]} badge />}
                </span>
              )}
              <span>{view.statusLabel}</span>
            </span>
            {view.status !== 'done' && view.status !== 'deferred' && view.leverage > 0 && (
              <span className={`trading-unblocks${view.leverage >= 4 ? ' big' : ''}`}>unblocks {view.leverage}</span>
            )}
          </footer>
        </div>
      </div>
    </div>
  )
}
