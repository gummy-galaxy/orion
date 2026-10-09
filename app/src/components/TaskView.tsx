import { memo, type CSSProperties } from 'react'
import { Handle, Position, useStore, type NodeProps } from '@xyflow/react'
import { STATUS_LABEL, getTaskTag, type TaskNode } from '../model'
import { SourceBadges } from './SourceBadges'
import { useLeverage, useMarked, useSources, useStatus, useTilt, useTraceRole } from '../state'
import { CardArt } from './CardArt'
import { CardTilt } from './CardTilt'
import { FarTag } from './FarTag'
import { Lock } from './Lock'

const WHO_LABEL = { you: 'Your move', review: 'Waiting on review', ci: 'Waiting on CI' }
const TYPE_LINE: Record<string, string> = { pr: 'Pull request', placeholder: 'Expected PR', step: 'Step', gate: 'Gate' }
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
  const tilt = useTilt(id)
  const held = tilt !== undefined ? ' in-hand' : ''
  const tiltStyle = tilt !== undefined ? ({ '--tilt': `${tilt}deg` } as CSSProperties) : undefined

  if (data.itemKind === 'note') {
    const className = `card note${trace ? ' tr-' + trace : ''}`
    const compact = (
      <>
        <div className="meta">
          <span>Note</span>
        </div>
        <div className="note-text">{data.label || 'Empty note'}</div>
        <SourceBadges sources={sources} />
      </>
    )

    return (
      <div className={`${className} tcg${held}`} style={tiltStyle}>
        <Handle type="target" position={Position.Left} />
        {far ? (
          <FarTag className={className}>{compact}</FarTag>
        ) : (
          <>
            <div className="tcg-title">
              <span className="tcg-name">Note</span>
            </div>
            <div className="tcg-text note-text">{data.label || 'Empty note'}</div>
            <div className="tcg-foot">
              <span className="meta-tag">Passes blocking through</span>
              <SourceBadges sources={sources} />
            </div>
          </>
        )}
        <Handle type="source" position={Position.Right} />
      </div>
    )
  }

  const className = `card st-${status}${data.itemKind === 'placeholder' ? ' placeholder' : ''}${data.itemKind === 'gate' ? ' gate' : ''}${trace ? ' tr-' + trace : ''}${attention ? ' attn' : ''}`
  const statusLabel = (
    <span className="st" title={STATUS_LABEL[status]}>
      {status === 'blocked' && <Lock />}
      <span className="st-label">{STATUS_LABEL[status]}</span>
    </span>
  )
  const compact = (
    <>
      <div className="meta">
        {data.itemKind === 'gate' && <span className="gate-mark" title="Gate: done once everything it waits on is" />}
        <span className="meta-tag" title={getTaskTag(data)}>
          {getTaskTag(data)}
        </span>
        {data.github?.checks && (
          <span className={`check-dot check-${data.github.checks.toLowerCase()}`} title={`Checks: ${data.github.checks.toLowerCase()}`} />
        )}
        {statusLabel}
      </div>
      <div className="label">{data.label}</div>
      <SourceBadges sources={sources} />
    </>
  )
  const github = data.github
  const flavor = github?.title && github.title !== data.label ? github.title : null
  const open = status !== 'done' && status !== 'deferred'
  const foil = open && data.who === 'you' ? ' foil' : ''

  return (
    <CardTilt>
      <div className={`${className} tcg${held}${foil}`} style={tiltStyle}>
        <Handle type="target" position={Position.Left} />
        <div className="tcg-title">
          <span className="tcg-name">{data.label}</span>
          {open && leverage > 0 && (
            <span className={`tcg-cost${leverage >= 4 ? ' big' : ''}`} title={`Unblocks ${leverage}`}>
              {leverage}
            </span>
          )}
        </div>
        <CardArt id={id} sources={sources} tone={status} />
        {far ? (
          <FarTag className={className}>{compact}</FarTag>
        ) : (
          <>
            <div className="tcg-type">
              {data.itemKind === 'gate' && <span className="gate-mark" title="Gate: done once everything it waits on is" />}
              <span className="tcg-type-name" title={data.repo}>
                {TYPE_LINE[data.itemKind ?? 'step'] ?? 'Step'}
              </span>
              {statusLabel}
            </div>
            <div className="tcg-text">
              {data.note && <p>{data.note}</p>}
              {flavor && <p className="tcg-flavor">{flavor}</p>}
              {!data.note && !flavor && <p className="tcg-flavor">{github?.author ? `by ${github.author}` : 'No notes yet.'}</p>}
            </div>
            <div className="tcg-foot">
              <span className="meta-tag" title={getTaskTag(data)}>
                {getTaskTag(data)}
              </span>
              {github?.checks && (
                <span className={`check-dot check-${github.checks.toLowerCase()}`} title={`Checks: ${github.checks.toLowerCase()}`} />
              )}
              <SourceBadges sources={sources} />
              {typeof github?.additions === 'number' && (
                <span className="tcg-pt" title={`${github.additions + github.deletions} lines`}>
                  +{github.additions}/−{github.deletions}
                </span>
              )}
            </div>
          </>
        )}
        {open && data.who && <span className={`who who-${data.who}`} title={WHO_LABEL[data.who]} />}
        <span className="tcg-shine" />
        <Handle type="source" position={Position.Right} />
      </div>
    </CardTilt>
  )
})
