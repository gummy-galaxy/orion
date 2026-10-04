import type { GroupStats } from './derive'
import { isCluster, type AppNode, type ClusterData } from './model'

type Props = {
  nodes: AppNode[]
  groups: Map<string, GroupStats>
  root: string | null
  open: (id: string | null) => void
  readyTotal: number
  hide: () => void
}

/** A stable list of every group, in canvas order, for jumping between bodies of work. */
export function Sidebar({ nodes, groups, root, open, readyTotal, hide }: Props) {
  const clusters = nodes.filter(isCluster)
  const children = (parent: string | undefined) => clusters.filter((c) => c.parentId === parent)

  const row = (c: AppNode, depth: number) => {
    const s = groups.get(c.id)
    const pct = s && s.total ? Math.round((s.done / s.total) * 100) : 0
    return (
      <li key={c.id}>
        <button
          type="button"
          className={`side-row${c.id === root ? ' current' : ''}`}
          style={{ paddingLeft: 10 + depth * 14 }}
          onClick={() => open(c.id)}
          title={(c.data as ClusterData).blurb}
        >
          <span className="side-bar" aria-hidden="true">
            <span style={{ width: `${pct}%` }} />
          </span>
          <span className="side-label">{(c.data as ClusterData).label}</span>
          <span className="side-meta">
            {s && s.ready > 0 && <span className="side-ready">{s.ready} ready</span>}
            {s && s.outside > 0 && <span className="side-lev">↗{s.outside}</span>}
          </span>
        </button>
        {children(c.id).length > 0 && <ul>{children(c.id).map((k) => row(k, depth + 1))}</ul>}
      </li>
    )
  }

  return (
    <aside className="sidebar">
      <div className="side-head">
        <strong>Orion</strong>
        <button type="button" className="side-hide" onClick={hide} title="Hide the group list">
          ‹
        </button>
      </div>
      <button type="button" className={`side-row all${root === null ? ' current' : ''}`} onClick={() => open(null)}>
        <span className="side-label">All work</span>
        <span className="side-meta">
          <span className="side-ready">{readyTotal} ready</span>
        </span>
      </button>
      <ul className="side-list">{children(undefined).map((c) => row(c, 0))}</ul>
      <p className="side-foot">The bar shows how much of each group is done. ↗ counts open work outside the group that waits on it.</p>
    </aside>
  )
}
