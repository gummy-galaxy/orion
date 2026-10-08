import { useContext, type ReactNode } from 'react'
import { Handle, Position, useStore, type NodeProps } from '@xyflow/react'
import { ActionsContext, DerivedContext } from './derive'
import { STATUS_LABEL, getTaskTag, type ClusterNode, type GhostNode, type TaskNode } from './model'
import { SourceBadges } from './SourceBadges'

const WHO_LABEL = { you: 'Your move', review: 'Waiting on review', ci: 'Waiting on CI' }

function Lock() {
  return (
    <svg viewBox="0 0 10 12" width="8" height="10" aria-hidden="true" className="lock">
      <path d="M2.5 5V3.5a2.5 2.5 0 0 1 5 0V5" fill="none" stroke="currentColor" strokeWidth="1.4" />
      <rect x="1" y="5" width="8" height="6.5" rx="1.2" fill="currentColor" />
    </svg>
  )
}

function Ring({ done, total, size = 22 }: { done: number; total: number; size?: number }) {
  const radius = 8
  const circumference = 2 * Math.PI * radius

  return (
    <svg viewBox="0 0 20 20" width={size} height={size} className="ring" aria-hidden="true">
      <circle cx="10" cy="10" r={radius} className="ring-bg" />
      <circle
        cx="10"
        cy="10"
        r={radius}
        className="ring-fg"
        strokeDasharray={`${total ? (done / total) * circumference : 0} ${circumference}`}
        transform="rotate(-90 10 10)"
      />
    </svg>
  )
}

/** Zoom below which a card's details sit in a tag over its body that keeps one on-screen size. */
const FAR_ZOOM = 0.3

function FarTag({ className, children }: { className: string; children: ReactNode }) {
  return (
    <div className="pop-place">
      <div className={`${className} far-card`}>{children}</div>
    </div>
  )
}

export function TaskView({ id, data }: NodeProps<TaskNode>) {
  const derived = useContext(DerivedContext)!
  const far = useStore((state) => state.transform[2] < FAR_ZOOM)
  const status = derived.status.get(id) ?? 'ready'
  const leverage = derived.leverage.get(id) ?? 0
  const trace = derived.trace?.get(id)
  const attention = derived.attention?.get(id)

  if (data.itemKind === 'note') {
    const className = `card note${trace ? ' tr-' + trace : ''}`
    const body = (
      <>
        <div className="meta">
          <span>Note</span>
        </div>
        <div className="note-text">{data.label || 'Empty note'}</div>
        <SourceBadges sources={derived.sources.get(id) ?? []} />
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

  const className = `card st-${status}${data.itemKind === 'placeholder' ? ' placeholder' : ''}${trace ? ' tr-' + trace : ''}${attention ? ' attn' : ''}`
  const body = (
    <>
      <div className="meta">
        <span className="meta-tag" title={getTaskTag(data)}>
          {getTaskTag(data)}
        </span>
        {data.github?.checks && (
          <span className={`check-dot check-${data.github.checks.toLowerCase()}`} title={`Checks: ${data.github.checks.toLowerCase()}`} />
        )}
        <span className="st" title={STATUS_LABEL[status]}>
          {status === 'blocked' && <Lock />}
          <span className="st-label">{STATUS_LABEL[status]}</span>
        </span>
      </div>
      <div className="label">{data.label}</div>
      {status !== 'done' && status !== 'deferred' && leverage > 0 && <span className={`lev${leverage >= 4 ? ' big' : ''}`}>unblocks {leverage}</span>}
      {status !== 'done' && data.who && <span className={`who who-${data.who}`} title={WHO_LABEL[data.who]} />}
      <SourceBadges sources={derived.sources.get(id) ?? []} />
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

export function GhostView({ data }: NodeProps<GhostNode>) {
  const derived = useContext(DerivedContext)!
  const trace = derived.trace?.get(data.taskId)

  return (
    <div className={`ghost st-${data.status} side-${data.side}${trace ? ' tr-' + trace : ''}`} title={`Jump to ${data.label}`}>
      {data.side === 'out' && <Handle type="target" position={Position.Left} isConnectable={false} />}
      <span className="ghost-where">
        {data.side === 'in' ? 'from' : 'to'} {data.where}
      </span>
      <span className="label">{data.label}</span>
      <span className="ghost-status">{STATUS_LABEL[data.status]}</span>
      <SourceBadges sources={derived.sources.get(data.taskId) ?? []} />
      {data.side === 'in' && <Handle type="source" position={Position.Right} isConnectable={false} />}
    </div>
  )
}

export function ClusterView({ id, data }: NodeProps<ClusterNode>) {
  const derived = useContext(DerivedContext)!
  const actions = useContext(ActionsContext)!
  const stats = derived.groups.get(id) ?? { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }
  const collapsed = derived.collapsed.has(id)
  const trace = derived.trace?.get(id)
  const attention = derived.attention?.get(id)

  return (
    <div className={`cluster${collapsed ? ' is-collapsed' : ''}${trace ? ' tr-' + trace : ''}`}>
      <Handle type="target" position={Position.Left} isConnectable={false} />
      {collapsed ? (
        <div className="pop drag">
          <span className="pop-anchor" />
          <div className="pop-place">
            <div className={`bubble${attention ? ' attn' : ''}`}>
              <div className="bubble-title">
                <Ring done={stats.done} total={stats.total} size={16} />
                <strong>{data.label}</strong>
              </div>
              <span className="bubble-stats">
                {stats.done}/{stats.total} done · {stats.ready} ready · {stats.blocked} blocked
              </span>
              {stats.outside > 0 && <span className="bubble-lev">unblocks {stats.outside} outside</span>}
              <SourceBadges sources={derived.sources.get(id) ?? []} inBubble />
            </div>
          </div>
        </div>
      ) : (
        <div className="cluster-head drag" title="Double-click to open">
          <Ring done={stats.done} total={stats.total} />
          <strong>{data.label}</strong>
          <span className="count">
            {stats.done}/{stats.total}
          </span>
          {stats.outside > 0 && <span className="lev-inline">unblocks {stats.outside} outside</span>}
          <span className="head-actions">
            {data.arrange !== 'custom' && (
              <button type="button" className="nodrag" onClick={() => actions.reflow(id)}>
                Reflow
              </button>
            )}
            <button type="button" className="nodrag" onClick={() => actions.open(id)}>
              Open
            </button>
          </span>
        </div>
      )}
      {!collapsed && <SourceBadges sources={derived.sources.get(id) ?? []} />}
      <Handle type="source" position={Position.Right} isConnectable={false} />
    </div>
  )
}
