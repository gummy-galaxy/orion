import type { CardView } from '../cardView'
import { SourceBadges } from './SourceBadges'
import { StatusIcon } from './StatusIcon'

export function PlainCard({ view }: { view: CardView }) {
  if (view.kind === 'note') {
    return (
      <>
        <div className="plain-note-kind">Note</div>
        <div className="plain-note-text">{view.title || 'Empty note'}</div>
        <SourceBadges sources={view.sources} />
      </>
    )
  }

  const checkLabel = view.checks === 'passing' ? 'passing' : view.checks === 'failing' ? 'failing' : 'pending'
  const checkGlyph = view.checks === 'passing' ? '✓' : view.checks === 'failing' ? '×' : '·'

  return (
    <>
      <div className="plain-title">{view.title}</div>
      <div className="plain-meta">
        {view.kind === 'gate' && (
          <span className="plain-gate" title="Gate: done once everything it waits on is">
            ◇
          </span>
        )}
        <span className="plain-tag" title={view.tag}>
          {view.tag}
        </span>
        {(view.who || view.checks || (view.status !== 'done' && view.status !== 'deferred' && view.leverage > 0)) && (
          <span className="plain-details">
            {view.who && <span title={view.whoLabel}>{view.whoLabel}</span>}
            {view.checks && (
              <span className="plain-check" aria-label={`Checks: ${checkLabel}`} title={`Checks: ${checkLabel}`}>
                {checkGlyph}
              </span>
            )}
            {view.status !== 'done' && view.status !== 'deferred' && view.leverage > 0 && (
              <span>unblocks {view.leverage}</span>
            )}
          </span>
        )}
        <span className="plain-status" title={view.statusLabel}>
          {view.status === 'blocked' && <StatusIcon status="blocked" />}
          {view.statusLabel}
        </span>
      </div>
      <SourceBadges sources={view.sources} />
    </>
  )
}
