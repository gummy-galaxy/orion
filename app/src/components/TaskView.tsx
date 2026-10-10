import { memo } from 'react'
import { Handle, Position, useStore, type NodeProps } from '@xyflow/react'
import { SHAPE_LABEL, STATUS_LABEL, TASK_HEIGHT, TASK_WIDTH, getPullRef, getTaskTag, type PullDetails, type TaskNode } from '../model'
import { SourceBadges } from './SourceBadges'
import { useLeverage, useMarked, useSources, useStatus, useTint, useTraceRole } from '../state'
import { FarTag } from './FarTag'
import { Lock } from './Lock'
import { OpenInVscode } from './OpenInVscode'
import { ShapeOutline } from './ShapeOutline'

const WHO_LABEL = { you: 'Your move', review: 'Waiting on review', ci: 'Waiting on CI' }
/** Zoom below which a card's details sit in a tag over its body that keeps one on-screen size. */
const FAR_ZOOM = 0.3

// Memoized because React Flow re-renders every node wrapper whenever the canvas passes new handlers.
export const TaskView = memo(function TaskView({ id, data, width, height }: NodeProps<TaskNode>) {
  const far = useStore((state) => state.transform[2] < FAR_ZOOM)
  const status = useStatus(id)
  const leverage = useLeverage(id)
  const trace = useTraceRole(id)
  const attention = useMarked(id)
  const sources = useSources(id)
  const pullRequestUrl = data.itemKind === 'pr' ? sources.find((source) => source.href?.startsWith('https://github.com/'))?.href : undefined
  const checks = (getPullRef(data)?.details as PullDetails | undefined)?.checks
  const tint = useTint(id)

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

  if (data.itemKind === 'component') {
    const shape = data.shape ?? 'service'
    const className = `card component shape-${shape}${tint ? ' tint-' + tint : ''}${trace ? ' tr-' + trace : ''}`
    const body = (
      <>
        <ShapeOutline shape={shape} width={width ?? TASK_WIDTH} height={height ?? TASK_HEIGHT} />
        <div className="meta">
          <span className="component-mark" title="Component: a part of the system, not work" />
          <span className="meta-tag" title={getTaskTag(data)}>
            {data.repo ?? SHAPE_LABEL[shape]}
          </span>
        </div>
        <div className="label">{data.label || 'Untitled component'}</div>
        {data.note && (
          <div className="component-note" title={data.note}>
            {data.note}
          </div>
        )}
        <div className="card-actions">
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
  }

  const className = `card st-${status}${data.itemKind === 'placeholder' ? ' placeholder' : ''}${data.itemKind === 'gate' ? ' gate' : ''}${trace ? ' tr-' + trace : ''}${attention ? ' attn' : ''}`
  const body = (
    <>
      <div className="meta">
        {data.itemKind === 'gate' && <span className="gate-mark" title="Gate: done once everything it waits on is" />}
        <span className="meta-tag" title={getTaskTag(data)}>
          {getTaskTag(data)}
        </span>
        {checks && <span className={`check-dot check-${checks.toLowerCase()}`} title={`Checks: ${checks.toLowerCase()}`} />}
        <span className="st" title={STATUS_LABEL[status]}>
          {status === 'blocked' && <Lock />}
          <span className="st-label">{STATUS_LABEL[status]}</span>
        </span>
      </div>
      <div className="label">{data.label}</div>
      {status !== 'done' && status !== 'deferred' && leverage > 0 && <span className={`lev${leverage >= 4 ? ' big' : ''}`}>unblocks {leverage}</span>}
      {status !== 'done' && data.who && <span className={`who who-${data.who}`} title={WHO_LABEL[data.who]} />}
      <div className="card-actions">
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
