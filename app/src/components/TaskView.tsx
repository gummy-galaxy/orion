import { memo } from 'react'
import { Handle, Position, useStore, type NodeProps } from '@xyflow/react'
import { READINESS_LABEL, STATUS_LABEL, getPullReadiness, getPullRef, getTaskTag, type PullDetails, type TaskNode } from '../model'
import { SourceBadges } from './SourceBadges'
import { useLeverage, useMarked, useSources, useStatus, useTraceRole } from '../state'
import { FarTag } from './FarTag'
import { ChecksIcon } from './ChecksIcon'
import { MergePullRequest } from './MergePullRequest'
import { OpenInVscode } from './OpenInVscode'
import { StatusIcon } from './StatusIcon'
import { WhoBadge } from './WhoBadge'

/** Zoom below which a card's details sit in a tag over its body that keeps one on-screen size. */
const FAR_ZOOM = 0.3

// Memoized because React Flow re-renders every node wrapper whenever the canvas passes new handlers.
export const TaskView = memo(function TaskView({ id, data }: NodeProps<TaskNode>) {
  const far = useStore((state) => state.transform[2] < FAR_ZOOM)
  const status = useStatus(id)
  const leverage = useLeverage(id)
  const trace = useTraceRole(id)
  const attention = useMarked(id)
  const sources = useSources(id)
  const pullRequestUrl = data.itemKind === 'pr' ? sources.find((source) => source.href?.startsWith('https://github.com/'))?.href : undefined
  const pullRef = getPullRef(data)
  const pullDetails = pullRef?.details as PullDetails | undefined
  const readiness = getPullReadiness(pullDetails)
  // Work parked or blocked by hand stays that way even when GitHub would merge it.
  const readyToMerge = readiness === 'mergeable' && (status === 'review' || status === 'ready' || status === 'active')
  const statusLabel = readyToMerge ? READINESS_LABEL.mergeable : STATUS_LABEL[status]

  if (data.itemKind === 'note') {
    const className = `card note${trace ? ' tr-' + trace : ''}`
    const body = (
      <>
        <div className="meta">
          <span>Note</span>
        </div>
        <div className="note-text">{data.label || 'Empty note'}</div>
        <SourceBadges sources={sources} />
      </>
    )

    return (
      <div className={className}>
        <Handle type="target" position={Position.Left} />
        {far ? <FarTag className={className}>{body}</FarTag> : body}
        <Handle type="source" position={Position.Right} />
      </div>
    )
  }

  const className = `card st-${status}${data.itemKind === 'placeholder' ? ' placeholder' : ''}${data.itemKind === 'gate' ? ' gate' : ''}${trace ? ' tr-' + trace : ''}${attention ? ' attn' : ''}${readyToMerge ? ' ready-to-merge' : ''}`
  const body = (
    <>
      <div className="meta">
        {data.itemKind === 'gate' && <span className="gate-mark" title="Gate: done once everything it waits on is" />}
        <span className="meta-tag" title={getTaskTag(data)}>
          {getTaskTag(data)}
        </span>
        <span className="st" title={readiness && !readyToMerge ? `${statusLabel} · ${READINESS_LABEL[readiness]}` : statusLabel}>
          {readyToMerge ? (
            <ChecksIcon readiness="mergeable" />
          ) : (
            <span className="status-mark">
              <StatusIcon status={status} />
              {readiness && <ChecksIcon readiness={readiness} title={READINESS_LABEL[readiness]} badge />}
            </span>
          )}
          <span className="st-label">{statusLabel}</span>
        </span>
      </div>
      <div className="label">{data.label}</div>
      {status !== 'done' && status !== 'deferred' && leverage > 0 && <span className={`lev${leverage >= 4 ? ' big' : ''}`}>unblocks {leverage}</span>}
      {status !== 'done' && data.who && <WhoBadge who={data.who} />}
      <div className="card-actions">
        {readyToMerge && pullRef?.url && pullDetails?.head && <MergePullRequest url={pullRef.url} head={pullDetails.head} />}
        {pullRequestUrl && <OpenInVscode url={pullRequestUrl} />}
        <SourceBadges sources={sources} />
      </div>
    </>
  )

  return (
    <div className={className}>
      <Handle type="target" position={Position.Left} />
      {far ? <FarTag className={className}>{body}</FarTag> : body}
      <Handle type="source" position={Position.Right} />
    </div>
  )
})
