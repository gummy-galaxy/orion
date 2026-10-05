import { useContext, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { useStore } from '@xyflow/react'
import { DerivedContext, type Derived } from './derive'
import { STATUS_LABEL, WHO_LABEL, reviewStage, type AppNode, type ClusterNode, type GhostNode, type TaskNode } from './model'
import { Lock, Ring, ServiceIcon } from './nodes'
import { SERVICE_NAME, badgeGroup, driver, taskTag, type Badge } from './sources'

/** How many of a group's contents the lens lists before counting the rest. */
const LENS_ITEMS = 12
const GAP = 10
const MARGIN = 8

const interactive = (target: EventTarget | null) =>
  target instanceof Element && !!target.closest('input, textarea, select, button, summary, [contenteditable="true"]')

function nodeAt(x: number, y: number) {
  return document.elementFromPoint(x, y)?.closest('.react-flow__node')?.getAttribute('data-id') ?? null
}

/** Hold Space over a card, note, or group to read it at full size without changing the zoom. */
export function Lens() {
  const [id, setId] = useState<string | null>(null)
  useEffect(() => {
    let held = false
    let x = -1
    let y = -1
    const move = (e: PointerEvent) => {
      x = e.clientX
      y = e.clientY
      if (held) setId(nodeAt(x, y))
    }
    const down = (e: KeyboardEvent) => {
      if (e.code !== 'Space' || e.metaKey || e.ctrlKey || e.altKey || interactive(e.target)) return
      // Keeps Space from toggling a focused card's selection or turning on the canvas's pan key.
      e.preventDefault()
      e.stopPropagation()
      if (e.repeat) return
      held = true
      setId(nodeAt(x, y))
    }
    const stop = () => {
      held = false
      setId(null)
    }
    const up = (e: KeyboardEvent) => e.code === 'Space' && stop()
    window.addEventListener('pointermove', move, { passive: true })
    window.addEventListener('keydown', down, true)
    window.addEventListener('keyup', up)
    window.addEventListener('blur', stop)
    window.addEventListener('pointerdown', stop)
    return () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('keydown', down, true)
      window.removeEventListener('keyup', up)
      window.removeEventListener('blur', stop)
      window.removeEventListener('pointerdown', stop)
    }
  }, [])

  const target = useStore((s) => {
    const n = id ? s.nodeLookup.get(id) : undefined
    return n?.type === 'ghost' ? s.nodeLookup.get((n as unknown as GhostNode).data.taskId) : n
  }) as AppNode | undefined
  const transform = useStore((s) => (id ? s.transform : null))
  const nodes = useStore((s) => (target?.type === 'cluster' ? s.nodes : null)) as AppNode[] | null
  const parent = useStore((s) => (target?.parentId ? s.nodeLookup.get(target.parentId) : undefined)) as ClusterNode | undefined
  const d = useContext(DerivedContext)!
  const ref = useRef<HTMLDivElement>(null)

  useLayoutEffect(() => {
    const lens = ref.current
    const host = lens?.parentElement
    const node = id ? document.querySelector(`.react-flow__node[data-id="${CSS.escape(id)}"]`) : null
    if (!lens || !host || !node) return
    const shown = (node.querySelector('.bubble, .far-card') ?? node).getBoundingClientRect()
    const box = host.getBoundingClientRect()
    const w = lens.offsetWidth
    const h = lens.offsetHeight
    const left = Math.min(Math.max(shown.left + shown.width / 2 - box.left - w / 2, MARGIN), box.width - w - MARGIN)
    const above = shown.top - box.top - GAP - h
    const below = shown.bottom - box.top + GAP
    const top = above >= MARGIN ? above : below + h <= box.height - MARGIN ? below : Math.max(MARGIN, box.height - h - MARGIN)
    lens.style.left = `${Math.max(left, MARGIN)}px`
    lens.style.top = `${top}px`
  }, [id, target, transform])

  if (!id || !target) return null
  return (
    <div ref={ref} className="lens-host" role="tooltip">
      {target.type === 'cluster' ? (
        <GroupLens group={target} nodes={nodes ?? []} d={d} />
      ) : (
        <TaskLens task={target} where={parent?.data.label} d={d} />
      )}
    </div>
  )
}

/** A card lists each source; a group counts its sources by service, since it gathers every card's. */
function SourceList({ sources, counted = false }: { sources: Badge[]; counted?: boolean }) {
  const shown = sources.filter((b) => b.icon !== 'orion')
  if (!shown.length) return null
  const byService = new Map<string, Badge[]>()
  for (const badge of shown) byService.set(badgeGroup(badge), [...(byService.get(badgeGroup(badge)) ?? []), badge])
  const rows = counted
    ? [...byService.values()].map((badges) => ({
        badge: badges[0],
        text: badges.length === 1 ? badges[0].label : `${badges.length} sources`,
      }))
    : shown.map((badge) => ({ badge, text: badge.label }))
  return (
    <ul className="lens-sources">
      {rows.map(({ badge, text }) => (
        <li key={badge.icon + badge.domain + text}>
          <ServiceIcon badge={badge} />
          <span>
            {SERVICE_NAME[badge.icon] ?? badge.domain}: {text}
          </span>
        </li>
      ))}
    </ul>
  )
}

function TaskLens({ task, where, d }: { task: TaskNode; where?: string; d: Derived }) {
  const { data } = task
  const st = d.status.get(task.id) ?? 'ready'
  const lev = d.leverage.get(task.id) ?? 0
  const github = driver(data)?.state
  const stage = st === 'review' ? reviewStage(github) : null
  const sources = d.sources.get(task.id) ?? []
  if (data.itemKind === 'note') {
    return (
      <div className="lens card note">
        <div className="meta">
          <span>Note{where && ` in ${where}`}</span>
        </div>
        <div className="note-text">{data.label || 'Empty note'}</div>
        <SourceList sources={sources} />
      </div>
    )
  }
  return (
    <div className={`lens card st-${st}${data.itemKind === 'placeholder' ? ' placeholder' : ''}${data.itemKind === 'gate' ? ' gate' : ''}`}>
      <div className="meta">
        {data.itemKind === 'gate' && <span className="gate-mark" />}
        <span className="meta-tag">{taskTag(data)}</span>
        {typeof github?.additions === 'number' && <span className="meta-lines">{github.additions + github.deletions} lines</span>}
        {github?.checks && <span className={`check-dot check-${github.checks.toLowerCase()}`} />}
        <span className={`st${stage ? ' stage-' + stage.replace(' ', '-').toLowerCase() : ''}`}>
          {st === 'blocked' && <Lock />}
          {stage ?? STATUS_LABEL[st]}
        </span>
      </div>
      <div className="label">{data.label}</div>
      {(lev > 0 || data.who) && st !== 'done' && (
        <div className="lens-chips">
          {st !== 'deferred' && lev > 0 && <span className="lens-chip">unblocks {lev}</span>}
          {data.who && <span className={`lens-chip who-chip who-chip-${data.who}`}>{WHO_LABEL[data.who]}</span>}
        </div>
      )}
      {data.note && <p className="lens-text">{data.note}</p>}
      {where && <span className="lens-where">In {where}</span>}
      <SourceList sources={sources} />
    </div>
  )
}

function GroupLens({ group, nodes, d }: { group: ClusterNode; nodes: AppNode[]; d: Derived }) {
  const s = d.groups.get(group.id) ?? { total: 0, done: 0, ready: 0, blocked: 0, outside: 0 }
  const children = nodes.filter((n) => n.parentId === group.id).sort((a, b) => a.position.y - b.position.y || a.position.x - b.position.x)
  return (
    <div className="lens lens-group">
      <div className="bubble-title">
        <Ring done={s.done} total={s.total} size={18} />
        <strong>{group.data.label}</strong>
      </div>
      <span className="bubble-stats">
        {s.done}/{s.total} done · {s.ready} ready · {s.blocked} blocked
      </span>
      {s.outside > 0 && <span className="bubble-lev">unblocks {s.outside} outside</span>}
      {group.data.blurb && <p className="lens-text">{group.data.blurb}</p>}
      {children.length > 0 && (
        <ul className="lens-items">
          {children.slice(0, LENS_ITEMS).map((n) => {
            if (n.type === 'cluster') {
              const g = d.groups.get(n.id)
              return (
                <li key={n.id}>
                  <Ring done={g?.done ?? 0} total={g?.total ?? 0} size={12} />
                  <span>{n.data.label}</span>
                  <span className="lens-count">
                    {g?.done ?? 0}/{g?.total ?? 0}
                  </span>
                </li>
              )
            }
            const st = d.status.get(n.id) ?? 'ready'
            const note = n.data.itemKind === 'note'
            return (
              <li key={n.id} className={note ? 'is-note' : `dot-${st}`}>
                <span className="lens-dot" />
                <span>{n.data.label || 'Empty note'}</span>
                <span className="lens-count">{note ? 'Note' : STATUS_LABEL[st]}</span>
              </li>
            )
          })}
          {children.length > LENS_ITEMS && <li className="lens-more">+{children.length - LENS_ITEMS} more</li>}
        </ul>
      )}
      <SourceList sources={d.sources.get(group.id) ?? []} counted />
    </div>
  )
}
