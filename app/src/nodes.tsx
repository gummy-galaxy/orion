import { useContext, useState, type CSSProperties } from 'react'
import { Handle, Position, type NodeProps } from '@xyflow/react'
import { ActionsContext, DerivedContext } from './derive'
import { STATUS_LABEL, type ClusterNode, type GhostNode, type TaskNode } from './model'
import { badgeGroup, driver, taskTag, type Badge } from './sources'

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

function Favicon({ domain }: { domain: string }) {
  const [failed, setFailed] = useState(false)
  return (
    <span className="source-favicon">
      <svg viewBox="0 0 20 20" aria-hidden="true">
        <circle cx="10" cy="10" r="7" fill="none" stroke="currentColor" strokeWidth="1.5" />
        <path d="M3 10h14M10 3c-4 4-4 10 0 14 4-4 4-10 0-14Z" fill="none" stroke="currentColor" strokeWidth="1.2" />
      </svg>
      {!failed && <img src={domain === 'orion' ? '/favicon.svg' : `https://${domain}/favicon.ico`} alt="" onError={() => setFailed(true)} />}
    </span>
  )
}

const SERVICE_NAME: Record<Badge['icon'], string | null> = { github: 'GitHub', jira: 'Jira', slack: 'Slack', hop: 'hop', orion: 'Orion', url: null }

function ServiceIcon({ badge }: { badge: Badge }) {
  switch (badge.icon) {
    case 'github':
      return (
        <span className="source-favicon source-icon-github">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path
              fill="currentColor"
              d="M12 .3a12 12 0 0 0-3.8 23.38c.6.12.82-.26.82-.57v-2.04c-3.34.72-4.04-1.61-4.04-1.61-.55-1.39-1.33-1.76-1.33-1.76-1.09-.74.08-.73.08-.73 1.2.09 1.84 1.24 1.84 1.24 1.07 1.83 2.8 1.3 3.49 1 .1-.78.42-1.3.76-1.6-2.67-.31-5.47-1.34-5.47-5.94 0-1.31.47-2.38 1.24-3.22-.14-.3-.54-1.52.1-3.18 0 0 1-.32 3.3 1.23a11.5 11.5 0 0 1 6 0c2.28-1.55 3.29-1.23 3.29-1.23.64 1.66.24 2.88.12 3.18a4.65 4.65 0 0 1 1.23 3.22c0 4.61-2.8 5.63-5.48 5.92.42.36.81 1.1.81 2.22v3.29c0 .32.22.69.83.57A12 12 0 0 0 12 .3"
            />
          </svg>
        </span>
      )
    case 'jira':
      return (
        <span className="source-favicon source-icon-jira">
          <svg viewBox="0 0 20 20" aria-hidden="true">
            <path fill="#2684ff" d="M10 1.5 18.5 10 10 18.5 7.6 16.1 13.7 10 7.6 3.9Z" />
            <path fill="#0052cc" d="M10 6.2 13.8 10 10 13.8 6.2 10ZM5.2 7.6 7.6 10 5.2 12.4 2.8 10Z" />
          </svg>
        </span>
      )
    case 'slack':
      return (
        <span className="source-favicon source-icon-slack">
          <svg viewBox="0 0 20 20" aria-hidden="true">
            <rect x="7" y="2" width="3" height="9" rx="1.5" fill="#36c5f0" />
            <rect x="9" y="7" width="9" height="3" rx="1.5" fill="#2eb67d" />
            <rect x="10" y="9" width="3" height="9" rx="1.5" fill="#ecb22e" />
            <rect x="2" y="10" width="9" height="3" rx="1.5" fill="#e01e5a" />
          </svg>
        </span>
      )
    case 'hop':
      return (
        <span className="source-favicon source-icon-hop">
          <svg viewBox="0 0 20 20" aria-hidden="true">
            <path d="M3 15c1.5-6 5.5-9 11-9" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
            <path d="m11.5 3 3.5 3-3.5 3" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
            <circle cx="4" cy="16" r="1.8" fill="currentColor" />
          </svg>
        </span>
      )
    default:
      return <Favicon domain={badge.domain} />
  }
}

function SourceBadges({ sources, inBubble = false }: { sources: Badge[]; inBubble?: boolean }) {
  const grouped = new Map<string, Badge[]>()
  for (const badge of sources.length ? sources : [{ icon: 'orion', domain: 'orion', label: 'Orion' } as Badge]) {
    const key = badgeGroup(badge)
    const list = grouped.get(key) ?? []
    if (!list.some((b) => b.label === badge.label)) list.push(badge)
    grouped.set(key, list)
  }
  return (
    <div className={`source-badges${inBubble ? ' in-bubble' : ''}`}>
      {[...grouped].map(([key, badges]) => {
        const name = SERVICE_NAME[badges[0].icon] ?? badges[0].domain
        const labels = badges.map((b) => b.label)
        return labels.length === 1 ? (
          <span key={key} className="source-domain" role="img" aria-label={`${name}: ${labels[0]}`} title={`${name}: ${labels[0]}`}>
            <ServiceIcon badge={badges[0]} />
          </span>
        ) : (
          <details
            key={key}
            className="source-domain source-domain-many nodrag"
            onPointerDown={(e) => e.stopPropagation()}
            onClick={(e) => e.stopPropagation()}
          >
            <summary aria-label={`${name}: ${labels.length} sources`} title={`${name}: ${labels.length} sources. Click to show them.`}>
              <ServiceIcon badge={badges[0]} />
              <span className="source-count">{labels.length}</span>
            </summary>
            <div className="source-menu">
              <strong>{name}</strong>
              <ul>
                {labels.map((label) => (
                  <li key={label}>{label}</li>
                ))}
              </ul>
            </div>
          </details>
        )
      })}
    </div>
  )
}

export function TaskView({ id, data }: NodeProps<TaskNode>) {
  const d = useContext(DerivedContext)!
  const st = d.status.get(id) ?? 'ready'
  const lev = d.leverage.get(id) ?? 0
  const tr = d.trace?.get(id)
  const attn = d.attention?.get(id)
  const github = driver(data)?.state
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
        {typeof github?.additions === 'number' && <span className="meta-lines">{github.additions + github.deletions} lines</span>}
        {github?.checks && <span className={`check-dot check-${github.checks.toLowerCase()}`} title={`Checks: ${github.checks.toLowerCase()}`} />}
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
            <button type="button" className="nodrag" onClick={() => actions.reflow(id)}>
              Reflow
            </button>
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
