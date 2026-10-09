import type { CSSProperties } from 'react'
import type { CardView } from '../cardView'
import { getCardInks } from '../skins/frameColor'
import { SourceBadges } from './SourceBadges'
import { TradingArtwork } from './TradingArtwork'
import { TradingKindIcon } from './TradingKindIcon'
import { TradingRaritySymbol } from './TradingRaritySymbol'

type ArtKind = Exclude<CardView['kind'], 'note'>

const KIND_LABEL: Record<ArtKind, string> = {
  step: 'Step',
  pr: 'Pull request',
  placeholder: 'Expected PR',
  gate: 'Gate',
}

function getCardStatus(view: CardView): { label: string; className: string } {
  if (view.status === 'done') return { label: 'Done', className: 'done' }

  if (view.who === 'you') return { label: 'Your move', className: 'you' }

  if (view.status === 'blocked') return { label: 'Blocked', className: 'blocked' }

  if (view.status === 'review' || view.who === 'review') return { label: 'In review', className: 'review' }

  if (view.status === 'deferred') return { label: 'Deferred', className: 'deferred' }

  return { label: 'Ready', className: 'ready' }
}

export function TradingCard({ view }: { view: CardView }) {
  if (view.kind === 'note') {
    return (
      <div className="trading-frame trading-note">
        <div className="trading-frame-border">
          <div className="trading-inner">
            <div className="trading-note-label">
              <TradingKindIcon kind="note" />
              <span>Note</span>
            </div>
            <div className="trading-note-text" title={view.title}>
              {view.title || 'Empty note'}
            </div>
            <SourceBadges sources={view.sources} />
          </div>
        </div>
      </div>
    )
  }

  const inks = getCardInks(view.repo, view.kind)
  const status = getCardStatus(view)
  const number = view.tag.match(/#(\d+)$/)?.[1]
  const repositoryName = view.repo?.split('/').at(-1)
  const style = { '--trading-ink-one': inks[0], '--trading-ink-two': inks[1] } as CSSProperties

  return (
    <div
      className={`trading-frame trading-kind-${view.kind} trading-${status.className}${view.rarity ? ` trading-${view.rarity}` : ''}${view.kind === 'placeholder' ? ' trading-expected' : ''}`}
      style={style}
    >
      <i className="trading-glow" aria-hidden="true" />
      <div className="trading-frame-border">
        <div className="trading-foil">
          <div className="trading-inner">
            <header className="trading-title">
              <h3 title={view.title}>{view.title}</h3>
              {number && <span className="trading-number">#{number}</span>}
            </header>
            <TradingArtwork view={view} kind={view.kind} inks={inks} status={status} />
            <div className="trading-type">
              <TradingKindIcon kind={view.kind} />
              <span>
                {KIND_LABEL[view.kind]}
                {repositoryName && ` · ${repositoryName}`}
              </span>
              {view.rarity && <TradingRaritySymbol rarity={view.rarity} upstream={view.upstream} />}
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
              {view.checks && (
                <span className={`trading-ci trading-ci-${view.checks}`} aria-label={`Checks: ${view.checks}`}>
                  <i />
                  CI
                </span>
              )}
              <span className="trading-pt">{status.label}</span>
            </footer>
          </div>
        </div>
      </div>
    </div>
  )
}
