import type { CardView } from '../cardView'
import { getCardArt } from '../skins/cardArt'
import { getFramePalette } from '../skins/frameColor'
import { SourceBadges } from './SourceBadges'

const KIND_LABEL: Record<Exclude<CardView['kind'], 'note'>, string> = {
  step: 'Step',
  pr: 'Pull request',
  placeholder: 'Planned work',
  gate: 'Gate',
}
const KIND_GLYPH: Record<Exclude<CardView['kind'], 'note'>, string> = {
  step: '✦',
  pr: '◆',
  placeholder: '▧',
  gate: '◇',
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

  const art = getCardArt(view.artSeed, view.kind)
  const isYourMove = view.who === 'you' && view.status !== 'done' && view.status !== 'deferred'
  const tagNumber = view.tag.match(/#(\d+)\b/)?.[1]
  const checkGlyph = view.checks === 'passing' ? '✓' : view.checks === 'failing' ? '×' : '…'

  return (
    <div className={`trading-frame palette-${getFramePalette(view.repo, view.kind)}${isYourMove ? ' trading-foil' : ''}`}>
      <div className="trading-title">
        {view.kind === 'gate' && <span className="trading-gate" aria-label="Gate" />}
        <span className="trading-name" title={view.title}>
          {view.title}
        </span>
        {view.leverage > 0 && (
          <span className="trading-cost" title={`Unblocks ${view.leverage}`} aria-label={`Unblocks ${view.leverage}`}>
            {view.leverage}
          </span>
        )}
      </div>
      <div className={`trading-art art-palette-${art.palettePick}`}>
        <svg
          viewBox="0 0 128 96"
          preserveAspectRatio="xMidYMid slice"
          aria-hidden="true"
          style={{ filter: `hue-rotate(${art.hueShift}deg)` }}
          dangerouslySetInnerHTML={{ __html: art.markup }}
        />
      </div>
      <div className="trading-type">
        <span className="trading-type-name">{KIND_LABEL[view.kind]}</span>
        <span className="trading-status">{view.statusLabel}</span>
        {view.sources.length ? (
          <SourceBadges sources={view.sources} />
        ) : (
          <span className="trading-set-symbol" aria-label={`${KIND_LABEL[view.kind]} symbol`}>
            {KIND_GLYPH[view.kind]}
          </span>
        )}
      </div>
      <div className="trading-text" title={view.note || view.tag}>
        <span className={view.note ? 'trading-note-copy' : 'trading-flavor'}>{view.note || view.tag}</span>
      </div>
      <div className="trading-bottom">
        <span className="trading-who" title={view.whoLabel || view.statusLabel}>
          {view.whoLabel || view.statusLabel}
        </span>
        {(view.checks || tagNumber) && (
          <span className="trading-pt" title={[view.checks && `Checks: ${view.checks}`, tagNumber && `#${tagNumber}`].filter(Boolean).join(', ')}>
            {view.checks && <span aria-label={`Checks: ${view.checks}`}>{checkGlyph}</span>}
            {tagNumber && <span>#{tagNumber}</span>}
          </span>
        )}
      </div>
    </div>
  )
}
