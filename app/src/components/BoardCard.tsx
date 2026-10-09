import type { CardView } from '../cardView'
import { getRepositoryColorIndex } from '../skins/repositoryColor'
import { SourceBadges } from './SourceBadges'

export function BoardCard({ view }: { view: CardView }) {
  if (view.kind === 'note') {
    return (
      <>
        <div className="board-note-kind">Note</div>
        <div className="board-note-text" title={view.title}>
          {view.title || 'Empty note'}
        </div>
        <SourceBadges sources={view.sources} />
      </>
    )
  }

  const checkLabel = view.checks === 'passing' ? 'passing' : view.checks === 'failing' ? 'failing' : 'pending'
  const checkGlyph = view.checks === 'passing' ? '✓' : view.checks === 'failing' ? '×' : '·'
  const moveLabel = view.who === 'you' ? 'You' : view.who === 'review' ? 'Review' : 'CI'

  return (
    <>
      <div className="board-chips">
        <span className="board-chip board-status-chip" role="img" aria-label={`Status: ${view.statusLabel}`} title={view.statusLabel} />
        {view.repo && (
          <span
            className={`board-chip board-repo-${getRepositoryColorIndex(view.repo)}`}
            role="img"
            aria-label={`Repository: ${view.repo}`}
            title={`Repository: ${view.repo}`}
          />
        )}
        {view.kind === 'gate' && <span className="board-chip board-gate-chip" role="img" aria-label="Gate" title="Gate" />}
      </div>
      <div className="board-title" title={view.title}>
        {view.title}
      </div>
      <div className="board-footer">
        {view.kind === 'gate' && (
          <span className="board-gate-mark" title="Gate" aria-label="Gate">
            ◇
          </span>
        )}
        <span className="board-status">{view.statusLabel}</span>
        {view.who && (
          <span className="board-move" title={view.whoLabel}>
            {moveLabel}
          </span>
        )}
        {view.checks && (
          <span className="board-checks" aria-label={`Checks: ${checkLabel}`} title={`Checks: ${checkLabel}`}>
            {checkGlyph} 1
          </span>
        )}
        {view.status !== 'done' && view.status !== 'deferred' && view.leverage > 0 && (
          <span className="board-leverage" title={`Unblocks ${view.leverage}`}>
            ↗ {view.leverage}
          </span>
        )}
        {view.tag && (
          <span className="board-tag" title={view.tag}>
            {view.tag}
          </span>
        )}
        <SourceBadges sources={view.sources} />
      </div>
    </>
  )
}
