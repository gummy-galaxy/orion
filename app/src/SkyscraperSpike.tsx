import { useEffect, useMemo, useRef, useState } from 'react'
import './SkyscraperSpike.css'

type Module = { id: string; label: string; tag: string; tower: string; needs: string[] }
type Point = { x: number; y: number; depth: number }

const TOWERS = [
  { id: 'storyteller', label: 'Storyteller perf', number: '01', color: 'mint' },
  { id: 'qa', label: 'Embedded QA', number: '02', color: 'blue' },
  { id: 'telemetry', label: 'Error & boot telemetry', number: '03', color: 'amber' },
] as const

/** Illustrative work; clearing these floors never writes to the real canvas. */
const MODULES: Module[] = [
  { id: 'contract', label: 'Define record contract', tag: 'storyteller', tower: 'storyteller', needs: [] },
  { id: 'loader', label: 'Load story modules', tag: 'storyteller', tower: 'storyteller', needs: ['contract'] },
  { id: 'snapshot', label: 'Capture Studio evidence', tag: 'qa', tower: 'storyteller', needs: ['loader'] },
  { id: 'perf', label: 'Measure two open copies', tag: 'benchmark', tower: 'storyteller', needs: ['loader'] },
  { id: 'release', label: 'Publish Storyteller', tag: 'release', tower: 'storyteller', needs: ['snapshot', 'perf'] },
  { id: 'gateway', label: 'Agent gateway actions', tag: 'flipbook', tower: 'qa', needs: [] },
  { id: 'mount', label: 'Mount embedded canvas', tag: 'flipbook', tower: 'qa', needs: ['gateway'] },
  { id: 'input', label: 'Verify viewport input', tag: 'qa', tower: 'qa', needs: ['mount'] },
  { id: 'image', label: 'Collect screenshot', tag: 'qa', tower: 'qa', needs: ['mount'] },
  { id: 'signoff', label: 'Sign off release QA', tag: 'release', tower: 'qa', needs: ['input', 'image', 'release'] },
  { id: 'consent', label: 'Consent boundary', tag: 'telemetry', tower: 'telemetry', needs: [] },
  { id: 'errors', label: 'Capture boot errors', tag: 'telemetry', tower: 'telemetry', needs: ['consent'] },
  { id: 'health', label: 'Report release health', tag: 'dashboard', tower: 'telemetry', needs: ['errors'] },
  { id: 'publish', label: 'Publish dashboard', tag: 'dashboard', tower: 'telemetry', needs: ['health', 'release'] },
]
const BY_ID = new Map(MODULES.map((module) => [module.id, module]))
const CARD_W = 208
const CARD_H = 72
const WALL_X = 210
const BAY = 248
const ROW = 88

function layout(done: Set<string>) {
  const open = MODULES.filter((module) => !done.has(module.id))
  const depth = new Map<string, number>()
  const visiting = new Set<string>()
  const findDepth = (id: string): number => {
    if (depth.has(id)) return depth.get(id)!
    if (visiting.has(id)) return 0
    visiting.add(id)
    const needs = BY_ID.get(id)?.needs.filter((need) => !done.has(need)) ?? []
    const value = needs.length ? Math.max(...needs.map(findDepth)) + 1 : 0
    visiting.delete(id)
    depth.set(id, value)
    return value
  }
  for (const module of open) findDepth(module.id)

  const points = new Map<string, Point>()
  const towers: { id: string; top: number; height: number; open: number; total: number }[] = []
  let top = 104
  for (const tower of TOWERS) {
    const members = open.filter((module) => module.tower === tower.id)
    const columns = new Map<number, Module[]>()
    for (const member of members) {
      const bay = depth.get(member.id) ?? 0
      columns.set(bay, [...(columns.get(bay) ?? []), member])
    }
    const rows = Math.max(1, ...[...columns.values()].map((column) => column.length))
    const height = Math.max(204, 82 + rows * ROW)
    for (const [bay, column] of columns) {
      column.forEach((module, row) => points.set(module.id, { x: WALL_X + bay * BAY, y: top + 64 + row * ROW, depth: bay }))
    }
    towers.push({ id: tower.id, top, height, open: members.length, total: MODULES.filter((m) => m.tower === tower.id).length })
    top += height + 24
  }
  const maxDepth = Math.max(0, ...[...depth.values()])
  return { points, towers, width: Math.max(1440, WALL_X + maxDepth * BAY + CARD_W + 30), height: top + 30 }
}

/** The load travels left, from a waiting floor into each open support. */
function supportPath(load: Point, support: Point) {
  const x0 = load.x - 2
  const y0 = load.y + CARD_H / 2
  const x1 = support.x + CARD_W + 2
  const y1 = support.y + CARD_H / 2
  if (y0 === y1) return 'M ' + x0 + ' ' + y0 + ' L ' + x1 + ' ' + y1
  const elbow = Math.max(x1 + 18, x0 - 28)
  const turn = y1 > y0 ? 10 : -10
  return (
    'M ' +
    x0 +
    ' ' +
    y0 +
    ' L ' +
    (elbow + 10) +
    ' ' +
    y0 +
    ' Q ' +
    elbow +
    ' ' +
    y0 +
    ' ' +
    elbow +
    ' ' +
    (y0 + turn) +
    ' L ' +
    elbow +
    ' ' +
    (y1 - turn) +
    ' Q ' +
    elbow +
    ' ' +
    y1 +
    ' ' +
    (elbow - 10) +
    ' ' +
    y1 +
    ' L ' +
    x1 +
    ' ' +
    y1
  )
}

export function SkyscraperSpike({ onClose }: { onClose: () => void }) {
  const [done, setDone] = useState(() => new Set<string>())
  const [hovered, setHovered] = useState<string | null>(null)
  const [falling, setFalling] = useState(() => new Set<string>())
  const settleTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const scene = useMemo(() => layout(done), [done])
  const open = MODULES.filter((module) => !done.has(module.id))
  const ready = open.filter((module) => scene.points.get(module.id)?.depth === 0)

  useEffect(
    () => () => {
      if (settleTimer.current) clearTimeout(settleTimer.current)
    },
    [],
  )

  const clear = (id: string) => {
    if (scene.points.get(id)?.depth !== 0) {
      setHovered(id)
      return
    }
    const dependents = new Set<string>()
    const visit = (current: string) => {
      for (const module of MODULES) {
        if (module.needs.includes(current) && !dependents.has(module.id)) {
          dependents.add(module.id)
          visit(module.id)
        }
      }
    }
    visit(id)
    setDone((previous) => new Set(previous).add(id))
    setFalling(dependents)
    setHovered(null)
    if (settleTimer.current) clearTimeout(settleTimer.current)
    settleTimer.current = setTimeout(() => setFalling(new Set()), 750)
  }

  const hoveredModule = hovered ? BY_ID.get(hovered) : undefined
  const supports = new Set(hoveredModule?.needs.filter((id) => !done.has(id)) ?? [])
  const dependents = new Set(MODULES.filter((module) => !done.has(module.id) && module.needs.includes(hovered ?? '')).map((m) => m.id))

  return (
    <section className="sky-spike" aria-label="Horizontal skyscrapers visual spike">
      <header className="sky-header">
        <div className="sky-heading">
          <span className="sky-kicker">ORION / VISUAL SPIKE 01</span>
          <h1>
            Horizontal skyscrapers<span className="sky-period">.</span>
          </h1>
          <p>Work stacks sideways. Open prerequisites carry the weight; clear one and the unsupported floors settle toward the foundation.</p>
        </div>
        <div className="sky-header-actions">
          <span className="sky-demo-tag">Illustrative work · no canvas changes</span>
          <button type="button" className="sky-exit" onClick={onClose}>
            Back to canvas <span aria-hidden="true">↗</span>
          </button>
        </div>
      </header>

      <div className="sky-toolbar">
        <div className="sky-metric">
          <strong>{String(open.length).padStart(2, '0')}</strong>
          <span>floors standing</span>
        </div>
        <div className="sky-metric sky-metric-ready">
          <strong>{String(ready.length).padStart(2, '0')}</strong>
          <span>against the wall</span>
        </div>
        <div className="sky-metric">
          <strong>{String(done.size).padStart(2, '0')}</strong>
          <span>cleared</span>
        </div>
        <div className="sky-toolbar-copy">
          <span className="sky-ready-key" />
          Click a teal floor to clear it. Hover a floor to see its supports.
        </div>
        <button
          type="button"
          className="sky-reset"
          onClick={() => {
            setDone(new Set())
            setFalling(new Set())
            setHovered(null)
          }}
        >
          Reset structure ↺
        </button>
      </div>

      <div className="sky-scroll">
        <div className="sky-stage" style={{ width: scene.width, height: scene.height }}>
          <div className="sky-gravity">
            <span className="sky-gravity-arrow" aria-hidden="true">
              ←
            </span>
            <span>GRAVITY / LOAD PATH</span>
          </div>
          <div className="sky-foundation" style={{ height: scene.height - 122 }}>
            <span>FOUNDATION</span>
          </div>
          {scene.towers.map((tower, index) => {
            const definition = TOWERS[index]
            return (
              <div
                key={tower.id}
                className={'sky-tower sky-tower-' + definition.color}
                style={{ top: tower.top, height: tower.height, width: scene.width - 32 }}
              >
                <div className="sky-tower-name">
                  <span className="sky-tower-index">{definition.number}</span>
                  <strong>{definition.label}</strong>
                  <span className="sky-tower-progress">
                    {tower.total - tower.open}/{tower.total} cleared
                  </span>
                </div>
                <div className="sky-bay-labels" aria-hidden="true">
                  <span>READY / RESTING</span>
                  <span>ONE SUPPORT</span>
                  <span>LOAD ABOVE</span>
                </div>
              </div>
            )
          })}
          <svg className="sky-links" width={scene.width} height={scene.height} viewBox={'0 0 ' + scene.width + ' ' + scene.height} aria-hidden="true">
            <defs>
              <marker id="sky-arrow" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto" markerUnits="userSpaceOnUse">
                <path d="M 1 1 L 8 4.5 L 1 8" fill="none" stroke="context-stroke" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
              </marker>
            </defs>
            {open.flatMap((module) => {
              const load = scene.points.get(module.id)
              if (!load) return []
              return module.needs
                .filter((id) => !done.has(id))
                .map((id) => {
                  const support = scene.points.get(id)
                  if (!support) return null
                  const active = hovered === module.id || hovered === id
                  const path = supportPath(load, support)
                  return (
                    <g key={module.id + '-' + id} className={'sky-link' + (active ? ' is-active' : '') + (hovered && !active ? ' is-muted' : '')}>
                      <path className="sky-link-rail" d={path} markerEnd="url(#sky-arrow)" />
                      <path className="sky-link-flow" d={path} />
                    </g>
                  )
                })
            })}
          </svg>
          {open.map((module) => {
            const point = scene.points.get(module.id)!
            const isReady = point.depth === 0
            const related = supports.has(module.id) || dependents.has(module.id)
            const waitingOn = module.needs.filter((id) => !done.has(id))
            return (
              <button
                type="button"
                key={module.id}
                className={
                  'sky-module' +
                  (isReady ? ' is-ready' : ' is-waiting') +
                  (hovered === module.id ? ' is-hovered' : '') +
                  (hovered && !related && hovered !== module.id ? ' is-muted' : '') +
                  (falling.has(module.id) ? ' is-falling' : '')
                }
                style={{ left: point.x, top: point.y }}
                aria-disabled={!isReady}
                aria-label={
                  module.label + '. ' + (isReady ? 'Ready to clear' : 'Waiting on ' + waitingOn.map((id) => BY_ID.get(id)?.label).join(' and '))
                }
                onMouseEnter={() => setHovered(module.id)}
                onMouseLeave={() => setHovered(null)}
                onFocus={() => setHovered(module.id)}
                onBlur={() => setHovered(null)}
                onClick={() => clear(module.id)}
              >
                <span className="sky-module-body">
                  <span className="sky-module-top">
                    <span>{module.tag}</span>
                    <span>{isReady ? 'READY' : waitingOn.length + ' SUPPORT' + (waitingOn.length === 1 ? '' : 'S')}</span>
                  </span>
                  <strong>{module.label}</strong>
                  <span className="sky-module-foot">{isReady ? 'CLEAR FLOOR ←' : 'LOAD BEARS LEFT ←'}</span>
                </span>
              </button>
            )
          })}
          {open.length === 0 && (
            <div className="sky-complete">
              ALL FLOORS CLEARED <span>✦</span>
            </div>
          )}
        </div>
      </div>
      <footer className="sky-footer">
        <span>ARROWS POINT TO SUPPORTS</span>
        <span>Only open prerequisites hold up a floor</span>
        <span>Experimental view · canvas positions are untouched</span>
      </footer>
    </section>
  )
}
