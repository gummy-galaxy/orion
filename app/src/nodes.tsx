import { useContext, type CSSProperties } from 'react'
import { Handle, Position, type NodeProps } from '@xyflow/react'
import { ActionsContext, DerivedContext } from './derive'
import { STATUS_LABEL, taskTag, type ClusterNode, type GhostNode, type TaskNode } from './model'

const WHO_LABEL = { you: 'Your move', review: 'Waiting on review', ci: 'Waiting on CI' }

function Lock() {
  return (
    <svg viewBox="0 0 10 12" width="8" height="10" aria-hidden="true" className="lock">
      <path d="M2.5 5V3.5a2.5 2.5 0 0 1 5 0V5" fill="none" stroke="currentColor" strokeWidth="1.4" />
      <rect x="1" y="5" width="8" height="6.5" rx="1.2" fill="currentColor" />
    </svg>
  )
}

/** Below this on-screen width, a folded group's bubble shows only its name. */
const BUBBLE_DETAIL_WIDTH = 150

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

function sourceInitials(source: string) {
  if (!source) return 'O'
  const name = source.split('/').at(-1) || source
  const word = (name.split(/[-_.]/).filter(Boolean).at(-1) || name).toUpperCase()
  const consonants = word.replace(/[^A-Z0-9]|[AEIOU]/g, '')
  return (consonants.length >= 2 ? consonants : word).slice(0, 2)
}

function sourceHue(source: string) {
  let hash = 0
  for (const char of source) hash = (hash * 31 + char.charCodeAt(0)) % 360
  return hash
}

function SourceBadges({ sources, inBubble = false }: { sources: string[]; inBubble?: boolean }) {
  const visible = sources.length ? sources : ['']
  return (
    <span
      className={`source-badges${inBubble ? ' in-bubble' : ''}`}
      role="img"
      aria-label={`Sources: ${visible.map((source) => source || 'Orion').join(', ')}`}
    >
      {visible.map((source) => (
        <span
          key={source || 'local'}
          className={`source-badge${source ? '' : ' is-local'}`}
          style={source ? ({ '--source-hue': sourceHue(source) } as CSSProperties) : undefined}
          title={source ? `Repository: ${source}` : 'Orion work item'}
          aria-hidden="true"
        >
          {sourceInitials(source)}
        </span>
      ))}
    </span>
  )
}

export function TaskView({ id, data }: NodeProps<TaskNode>) {
  const d = useContext(DerivedContext)!
  const st = d.status.get(id) ?? 'ready'
  const lev = d.leverage.get(id) ?? 0
  const tr = d.trace?.get(id)
  const attn = d.attention?.get(id)
  if (data.itemKind === 'note') {
    return (
      <div className={`card note${tr ? ' tr-' + tr : ''}`}>
        <Handle type="target" position={Position.Left} />
        <div className="meta">
          <span>Note</span>
        </div>
        <div className="note-text">{data.label || 'Empty note'}</div>
        <SourceBadges sources={d.sources.get(id) ?? []} />
        <Handle type="source" position={Position.Right} />
      </div>
    )
  }
  return (
    <div className={`card st-${st}${data.itemKind === 'placeholder' ? ' placeholder' : ''}${tr ? ' tr-' + tr : ''}${attn ? ' attn' : ''}`}>
      <Handle type="target" position={Position.Left} />
      <div className="meta">
        <span className="meta-tag" title={taskTag(data)}>
          {taskTag(data)}
        </span>
        {typeof data.github?.additions === 'number' && <span className="meta-lines">{data.github.additions + data.github.deletions} lines</span>}
        {data.github?.checks && (
          <span className={`check-dot check-${data.github.checks.toLowerCase()}`} title={`Checks: ${data.github.checks.toLowerCase()}`} />
        )}
        <span className="st">
          {st === 'blocked' && <Lock />}
          {STATUS_LABEL[st]}
        </span>
      </div>
      <div className="label">{data.label}</div>
      {st !== 'done' && st !== 'deferred' && lev > 0 && <span className={`lev${lev >= 4 ? ' big' : ''}`}>unblocks {lev}</span>}
      {st !== 'done' && data.who && <span className={`who who-${data.who}`} title={WHO_LABEL[data.who]} />}
      <SourceBadges sources={d.sources.get(id) ?? []} />
      <Handle type="source" position={Position.Right} />
    </div>
  )
}

export function GhostView({ data }: NodeProps<GhostNode>) {
  const d = useContext(DerivedContext)!
  const tr = d.trace?.get(data.taskId)
  return (
    <div className={`ghost st-${data.status} side-${data.side}${tr ? ' tr-' + tr : ''}`} title={`Jump to ${data.label}`}>
      {data.side === 'out' && <Handle type="target" position={Position.Left} isConnectable={false} />}
      <span className="ghost-where">
        {data.side === 'in' ? 'from' : 'to'} {data.where}
      </span>
      <span className="label">{data.label}</span>
      <span className="ghost-status">{STATUS_LABEL[data.status]}</span>
      <SourceBadges sources={d.sources.get(data.taskId) ?? []} />
      {data.side === 'in' && <Handle type="source" position={Position.Right} isConnectable={false} />}
    </div>
  )
}

export function ClusterView({ id, data, width }: NodeProps<ClusterNode>) {
  const d = useContext(DerivedContext)!
  const actions = useContext(ActionsContext)!
  const s = d.groups.get(id) ?? { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }
  const collapsed = d.collapsed.has(id)
  const tr = d.trace?.get(id)
  // A folded group raises a bubble from its center. The bubble keeps one on-screen size at every zoom.
  const screenWidth = (width ?? 300) * d.zoom
  const attn = d.attention?.get(id)
  return (
    <div className={`cluster${collapsed ? ' is-collapsed' : ''}${tr ? ' tr-' + tr : ''}`}>
      <Handle type="target" position={Position.Left} isConnectable={false} />
      {collapsed ? (
        <div className="pop drag" style={{ '--inv': 1 / d.zoom } as CSSProperties}>
          <span className="pop-anchor" />
          <div className="pop-place">
            <div className={`bubble${screenWidth < BUBBLE_DETAIL_WIDTH ? ' is-compact' : ''}${attn ? ' attn' : ''}`}>
              <div className="bubble-title">
                <Ring done={s.done} total={s.total} size={16} />
                <strong>{data.label}</strong>
              </div>
              <span className="bubble-stats">
                {s.done}/{s.total} done · {s.ready} ready · {s.blocked} blocked
              </span>
              {s.outside > 0 && <span className="bubble-lev">unblocks {s.outside} outside</span>}
              <SourceBadges sources={d.sources.get(id) ?? []} inBubble />
            </div>
          </div>
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
            {!d.gravityMode && (
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
      {!collapsed && <SourceBadges sources={d.sources.get(id) ?? []} />}
      <Handle type="source" position={Position.Right} isConnectable={false} />
    </div>
  )
}
