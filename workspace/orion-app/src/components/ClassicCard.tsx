import type { CardView } from '../cardView'
import { READINESS_LABEL } from '../model'
import { ChecksIcon } from './ChecksIcon'
import { MergePullRequest } from './MergePullRequest'
import { OpenInVscode } from './OpenInVscode'
import { SourceBadges } from './SourceBadges'
import { StatusIcon } from './StatusIcon'
import { WhoBadge } from './WhoBadge'

export function ClassicCard({ view }: { view: CardView }) {
  if (view.layout === 'note') {
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

  const { readiness } = view

  return (
    <>
      <div className="meta">
        {view.kind === 'gate' && <span className="gate-mark" title="Gate: done once everything it waits on is" />}
        <span className="meta-tag" title={view.tag}>
          {view.tag}
        </span>
        <span className="st" title={readiness && !view.readyToMerge ? `${view.statusLabel} · ${READINESS_LABEL[readiness]}` : view.statusLabel}>
          {view.readyToMerge ? (
            <ChecksIcon readiness="mergeable" />
          ) : (
            <span className="status-mark">
              <StatusIcon status={view.status} />
              {readiness && <ChecksIcon readiness={readiness} title={READINESS_LABEL[readiness]} badge />}
            </span>
          )}
          <span className="st-label">{view.statusLabel}</span>
        </span>
      </div>
      <div className="label">{view.title}</div>
      {view.status !== 'done' && view.status !== 'deferred' && view.leverage > 0 && (
        <span className={`lev${view.leverage >= 4 ? ' big' : ''}`}>unblocks {view.leverage}</span>
      )}
      {view.who && <WhoBadge who={view.who} />}
      <div className="card-actions">
        {view.merge && <MergePullRequest url={view.merge.url} head={view.merge.head} />}
        {view.pullRequestUrl && <OpenInVscode url={view.pullRequestUrl} />}
        <SourceBadges sources={view.sources} />
      </div>
    </>
  )
}
