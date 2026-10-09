import type { CardView } from '../cardView'
import { SourceBadges } from './SourceBadges'

export function ConventionalCard({ view }: { view: CardView }) {
  if (view.kind === 'note') {
    return (
      <>
        <div className="conventional-note-kind">Note</div>
        <div className="conventional-note-text">{view.title || 'Empty note'}</div>
        <SourceBadges sources={view.sources} />
      </>
    )
  }

  const checkLabel = view.checks === 'passing' ? 'passing' : view.checks === 'failing' ? 'failing' : 'pending'
  const checkGlyph = view.checks === 'passing' ? '✓' : view.checks === 'failing' ? '×' : '·'
  const whoText = view.who === 'you' ? 'Your move' : view.who === 'review' ? 'Review' : 'CI'

  return (
    <>
      <div className="conventional-title" title={view.title}>
        {view.kind === 'gate' && (
          <span className="conventional-gate" title="Gate: done once everything it waits on is">
            ◇
          </span>
        )}
        {view.title}
      </div>
      <div className="conventional-meta">
        <span className="conventional-status">{view.statusLabel}</span>
        <span className="conventional-tag" title={view.tag}>
          {view.tag}
        </span>
        {view.who && (
          <span className="conventional-who" title={view.whoLabel}>
            {whoText}
          </span>
        )}
        {view.checks && (
          <span
            className={`conventional-check conventional-check-${view.checks}`}
            aria-label={`Checks: ${checkLabel}`}
            title={`Checks: ${checkLabel}`}
          >
            {checkGlyph}
          </span>
        )}
        {view.status !== 'done' && view.status !== 'deferred' && view.leverage > 0 && (
          <span className="conventional-leverage">unblocks {view.leverage}</span>
        )}
      </div>
      <SourceBadges sources={view.sources} />
    </>
  )
}
