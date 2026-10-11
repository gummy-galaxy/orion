import type { CardView } from '../cardView'
import { ChecksIcon } from './ChecksIcon'
import { OpenInVscode } from './OpenInVscode'
import { SourceBadges } from './SourceBadges'
import { StatusIcon } from './StatusIcon'
import { WhoBadge } from './WhoBadge'

export function ClassicCard({ view }: { view: CardView }) {
  if (view.kind === 'note') {
    return (
      <>
        <div className="meta">
          <span>Note</span>
        </div>
        <div className="note-text">{view.title || 'Empty note'}</div>
        <SourceBadges sources={view.sources} />
      </>
    )
  }

  const checks = view.checks === 'passing' ? 'SUCCESS' : view.checks === 'failing' ? 'FAILURE' : 'PENDING'
  const checkTitle = view.checks === 'passing' ? 'success' : view.checks === 'failing' ? 'failure' : 'pending'

  return (
    <>
      <div className="meta">
        {view.kind === 'gate' && <span className="gate-mark" title="Gate: done once everything it waits on is" />}
        <span className="meta-tag" title={view.tag}>
          {view.tag}
        </span>
        {view.checks && <ChecksIcon checks={checks} title={`Checks: ${checkTitle}`} />}
        <span className="st" title={view.statusLabel}>
          <StatusIcon status={view.status} />
          <span className="st-label">{view.statusLabel}</span>
        </span>
      </div>
      <div className="label">{view.title}</div>
      {view.status !== 'done' && view.status !== 'deferred' && view.leverage > 0 && (
        <span className={`lev${view.leverage >= 4 ? ' big' : ''}`}>unblocks {view.leverage}</span>
      )}
      {view.who && <WhoBadge who={view.who} />}
      <div className="card-actions">
        {view.pullRequestUrl && <OpenInVscode url={view.pullRequestUrl} />}
        <SourceBadges sources={view.sources} />
      </div>
    </>
  )
}
