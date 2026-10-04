import { useContext } from 'react'
import { Handle, Position, type NodeProps } from '@xyflow/react'
import { ActionsContext, DerivedContext } from './derive'
import { STATUS_LABEL, type ClusterNode, type TaskNode } from './model'

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
  const r = 8
  const c = 2 * Math.PI * r
  return (
    <svg viewBox="0 0 20 20" width={size} height={size} className="ring" aria-hidden="true">
      <circle cx="10" cy="10" r={r} className="ring-bg" />
      <circle cx="10" cy="10" r={r} className="ring-fg" strokeDasharray={`${total ? (done / total) * c : 0} ${c}`} transform="rotate(-90 10 10)" />
    </svg>
  )
}

export function TaskView({ id, data }: NodeProps<TaskNode>) {
  const d = useContext(DerivedContext)!
  const st = d.status.get(id) ?? 'ready'
  const lev = d.leverage.get(id) ?? 0
  const tr = d.trace?.get(id)
  return (
    <div className={`card st-${st}${tr ? ' tr-' + tr : ''}`}>
      <Handle type="target" position={Position.Left} />
      <div className="meta">
        <span>{data.tag}</span>
        <span className="st">
          {st === 'blocked' && <Lock />}
          {STATUS_LABEL[st]}
        </span>
      </div>
      <div className="label">{data.label}</div>
      {st !== 'done' && lev > 0 && <span className={`lev${lev >= 4 ? ' big' : ''}`}>unblocks {lev}</span>}
      {st !== 'done' && data.who && <span className={`who who-${data.who}`} title={WHO_LABEL[data.who]} />}
      <Handle type="source" position={Position.Right} />
    </div>
  )
}

export function ClusterView({ id, data, width, height }: NodeProps<ClusterNode>) {
  const d = useContext(DerivedContext)!
  const actions = useContext(ActionsContext)!
  const s = d.groups.get(id) ?? { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }
  const collapsed = d.collapsed.has(id)
  const tr = d.trace?.get(id)
  // Summary text stays readable on screen but never outgrows the group's box.
  const fs = Math.min(13 / d.zoom, (width ?? 300) / 18, (height ?? 200) / 10)
  return (
    <div className={`cluster${collapsed ? ' is-collapsed' : ''}${tr ? ' tr-' + tr : ''}`}>
      <Handle type="target" position={Position.Left} isConnectable={false} />
      {collapsed ? (
        <div className="cluster-summary drag" style={{ fontSize: `${fs}px` }}>
          <Ring done={s.done} total={s.total} size={fs * 3.6} />
          <strong>{data.label}</strong>
          <span>
            {s.done}/{s.total} done · {s.ready} ready · {s.blocked} blocked
          </span>
          {s.outside > 0 && <span className="lev big">unblocks {s.outside} outside</span>}
        </div>
      ) : (
        <div className="cluster-head drag" title="Double-click to open">
          <Ring done={s.done} total={s.total} />
          <strong>{data.label}</strong>
          <span className="count">
            {s.done}/{s.total}
          </span>
          {s.outside > 0 && <span className="lev-inline">unblocks {s.outside} outside</span>}
          <span className="head-actions">
            <button type="button" className="nodrag" onClick={() => actions.reflow(id)}>
              Reflow
            </button>
            <button type="button" className="nodrag" onClick={() => actions.open(id)}>
              Open
            </button>
          </span>
        </div>
      )}
      <Handle type="source" position={Position.Right} isConnectable={false} />
    </div>
  )
}
