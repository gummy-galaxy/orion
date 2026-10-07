import { useContext, useEffect, useRef, useState, type ReactNode, type SyntheticEvent } from 'react'
import { Handle, Position, useStore, type NodeProps } from '@xyflow/react'
import { ActionsContext, DerivedContext, type SourceRef } from './derive'
import { STATUS_LABEL, WHO_LABEL, getTaskTag, type ClusterNode, type GhostNode, type TaskNode } from './model'

export function Lock() {
  return (
    <svg viewBox="0 0 10 12" width="8" height="10" aria-hidden="true" className="lock">
      <path d="M2.5 5V3.5a2.5 2.5 0 0 1 5 0V5" fill="none" stroke="currentColor" strokeWidth="1.4" />
      <rect x="1" y="5" width="8" height="6.5" rx="1.2" fill="currentColor" />
    </svg>
  )
}

export function Ring({ done, total, size = 22 }: { done: number; total: number; size?: number }) {
  const r = 8
  const c = 2 * Math.PI * r
  return (
    <svg viewBox="0 0 20 20" width={size} height={size} className="ring" aria-hidden="true">
      <circle cx="10" cy="10" r={r} className="ring-bg" />
      <circle cx="10" cy="10" r={r} className="ring-fg" strokeDasharray={`${total ? (done / total) * c : 0} ${c}`} transform="rotate(-90 10 10)" />
    </svg>
  )
}

export function Favicon({ domain }: { domain: string }) {
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

const stop = (event: SyntheticEvent) => event.stopPropagation()

function SourceLink({ source, label, className, children }: { source: SourceRef; label?: string; className?: string; children: ReactNode }) {
  return source.href ? (
    <a
      className={className}
      href={source.href}
      target="_blank"
      rel="noreferrer"
      aria-label={label}
      onPointerDown={stop}
      onClick={stop}
      onDoubleClick={stop}
    >
      {children}
    </a>
  ) : (
    <span className={className} role={label ? 'img' : undefined} aria-label={label}>
      {children}
    </span>
  )
}

function SourceMenu({ domain, name, sources }: { domain: string; name: string; sources: SourceRef[] }) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDetailsElement>(null)

  useEffect(() => {
    if (!open) return
    const dismiss = (event: PointerEvent) => {
      if (!ref.current?.contains(event.target as Node)) setOpen(false)
    }
    document.addEventListener('pointerdown', dismiss, true)
    return () => document.removeEventListener('pointerdown', dismiss, true)
  }, [open])

  return (
    <details
      ref={ref}
      open={open}
      className="source-domain source-domain-many nodrag"
      onToggle={(event) => setOpen(event.currentTarget.open)}
      onPointerDown={stop}
      onClick={stop}
    >
      <summary aria-label={`${name}: ${sources.length} sources`} title={`${name}: ${sources.length} sources. Click to show them.`}>
        <Favicon domain={domain} />
        <span className="source-count">{sources.length}</span>
      </summary>
      <div className="source-menu">
        <strong>{name}</strong>
        <ul>
          {sources.map((source) => (
            <li key={source.label}>
              <SourceLink source={source}>{source.label}</SourceLink>
            </li>
          ))}
        </ul>
      </div>
    </details>
  )
}

function SourceBadges({ sources, inBubble = false }: { sources: SourceRef[]; inBubble?: boolean }) {
  const domains = new Map<string, SourceRef[]>()
  for (const source of sources.length ? sources : [{ domain: 'orion', label: 'Orion' }]) {
    const entries = domains.get(source.domain) ?? []
    if (!entries.some((entry) => entry.label === source.label)) entries.push(source)
    domains.set(source.domain, entries)
  }
  return (
    <div className={`source-badges${inBubble ? ' in-bubble' : ''}`}>
      {[...domains].map(([domain, entries]) => {
        const name = domain === 'orion' ? 'Orion' : domain
        return entries.length === 1 ? (
          <span key={domain} className="source-domain nodrag" title={`${name}: ${entries[0].label}`}>
            <SourceLink source={entries[0]} label={`${name}: ${entries[0].label}`} className="source-link">
              <Favicon domain={domain} />
            </SourceLink>
          </span>
        ) : (
          <SourceMenu key={domain} domain={domain} name={name} sources={entries} />
        )
      })}
    </div>
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
  const d = useContext(DerivedContext)!
  const far = useStore((s) => s.transform[2] < FAR_ZOOM)
  const st = d.status.get(id) ?? 'ready'
  const lev = d.leverage.get(id) ?? 0
  const tr = d.trace?.get(id)
  const attn = d.attention?.get(id)
  if (data.itemKind === 'note') {
    const className = `card note${tr ? ' tr-' + tr : ''}`
    const body = (
      <>
        <div className="meta">
          <span>Note</span>
        </div>
        <div className="note-text">{data.label || 'Empty note'}</div>
        <SourceBadges sources={d.sources.get(id) ?? []} />
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
  const className = `card st-${st}${data.itemKind === 'placeholder' ? ' placeholder' : ''}${tr ? ' tr-' + tr : ''}${attn ? ' attn' : ''}`
  const body = (
    <>
      <div className="meta">
        <span className="meta-tag" title={getTaskTag(data)}>
          {getTaskTag(data)}
        </span>
        {data.github?.checks && (
          <span className={`check-dot check-${data.github.checks.toLowerCase()}`} title={`Checks: ${data.github.checks.toLowerCase()}`} />
        )}
        <span className="st" title={STATUS_LABEL[st]}>
          {st === 'blocked' && <Lock />}
          <span className="st-label">{STATUS_LABEL[st]}</span>
        </span>
      </div>
      <div className="label">{data.label}</div>
      {st !== 'done' && st !== 'deferred' && lev > 0 && <span className={`lev${lev >= 4 ? ' big' : ''}`}>unblocks {lev}</span>}
      {st !== 'done' && data.who && <span className={`who who-${data.who}`} title={WHO_LABEL[data.who]} />}
      <SourceBadges sources={d.sources.get(id) ?? []} />
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

export function ClusterView({ id, data }: NodeProps<ClusterNode>) {
  const d = useContext(DerivedContext)!
  const actions = useContext(ActionsContext)!
  const s = d.groups.get(id) ?? { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }
  const collapsed = d.collapsed.has(id)
  const tr = d.trace?.get(id)
  const attn = d.attention?.get(id)
  return (
    <div className={`cluster${collapsed ? ' is-collapsed' : ''}${tr ? ' tr-' + tr : ''}`}>
      <Handle type="target" position={Position.Left} isConnectable={false} />
      {collapsed ? (
        <div className="pop drag">
          <span className="pop-anchor" />
          <div className="pop-place">
            <div className={`bubble${attn ? ' attn' : ''}`}>
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
      {!collapsed && <SourceBadges sources={d.sources.get(id) ?? []} />}
      <Handle type="source" position={Position.Right} isConnectable={false} />
    </div>
  )
}
