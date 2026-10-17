import type { GroupStats } from '../derive'
import { isCluster, type AppNode, type ClusterData } from '../model'
import type { Workspaces } from '../persist'

type Props = {
  nodes: AppNode[]
  groups: Map<string, GroupStats>
  root: string | null
  open: (id: string | null) => void
  readyTotal: number
  hide: () => void
  workspaces: Workspaces
  switchWorkspace: (name: string) => Promise<void>
  newWorkspace: (name: string, label: string) => Promise<void>
  openSettings: () => void
  /** The shortcut that opens settings, shown beside its button. */
  settingsHint: string
}

/** A stable list of every group, in canvas order, for jumping between bodies of work. */
export function Sidebar({
  nodes,
  groups,
  root,
  open,
  readyTotal,
  hide,
  workspaces,
  switchWorkspace,
  newWorkspace,
  openSettings,
  settingsHint,
}: Props) {
  const clusters = nodes.filter(isCluster)
  const children = (parent: string | undefined) => clusters.filter((cluster) => cluster.parentId === parent)
  const current = workspaces.canvases.find((item) => item.name === workspaces.active)

  const create = async () => {
    const name = window.prompt('Canvas name (lowercase letters, digits, hyphens)')?.trim()

    if (!name) return

    const label = window.prompt('Canvas label', name)?.trim()

    if (label === undefined) return

    try {
      await newWorkspace(name, label || name)
    } catch (error) {
      window.alert(String(error))
    }
  }

  const row = (cluster: AppNode, depth: number) => {
    const stats = groups.get(cluster.id)
    const percent = stats && stats.total ? Math.round((stats.done / stats.total) * 100) : 0

    return (
      <li key={cluster.id}>
        <button
          type="button"
          className={`side-row${cluster.id === root ? ' current' : ''}`}
          style={{ paddingLeft: 10 + depth * 14 }}
          onClick={() => open(cluster.id)}
          title={(cluster.data as ClusterData).blurb}
        >
          {/* Groups that hold no work have no progress to show. */}
          {!!stats?.total && (
            <span className="side-bar" aria-hidden="true">
              <span style={{ width: `${percent}%` }} />
            </span>
          )}
          <span className="side-label">{(cluster.data as ClusterData).label}</span>
          <span className="side-meta">
            {stats && stats.ready > 0 && <span className="side-ready">{stats.ready} ready</span>}
            {stats && stats.outside > 0 && <span className="side-lev">↗{stats.outside}</span>}
          </span>
        </button>
        {children(cluster.id).length > 0 && <ul>{children(cluster.id).map((child) => row(child, depth + 1))}</ul>}
      </li>
    )
  }

  return (
    <aside className="sidebar">
      <div className="side-head" data-tauri-drag-region="deep">
        <button type="button" className="side-hide" onClick={hide} title="Hide the group list">
          ‹
        </button>
      </div>
      <details style={{ padding: 'var(--space-2) var(--space-5)', position: 'relative' }}>
        <summary style={{ cursor: 'pointer', fontSize: 'var(--text-size-body)' }} title="Choose a canvas">
          {current?.label ?? workspaces.active}
        </summary>
        <div style={{ display: 'grid', gap: 'var(--space-2)', padding: 'var(--space-4) 0' }}>
          {workspaces.canvases.map((item) => (
            <button
              key={item.name}
              type="button"
              className={`side-row${item.name === workspaces.active ? ' current' : ''}`}
              onClick={(event) => {
                event.currentTarget.closest('details')?.removeAttribute('open')
                void switchWorkspace(item.name).catch((error) => window.alert(String(error)))
              }}
            >
              {item.label}
            </button>
          ))}
          <button type="button" className="side-row" onClick={() => void create()}>
            New workspace…
          </button>
        </div>
      </details>
      <button type="button" className={`side-row all${root === null ? ' current' : ''}`} onClick={() => open(null)}>
        <span className="side-label">All work</span>
        <span className="side-meta">
          <span className="side-ready">{readyTotal} ready</span>
        </span>
      </button>
      <ul className="side-list">{children(undefined).map((cluster) => row(cluster, 0))}</ul>
      <p className="side-foot">The bar shows how much of each group is done. ↗ counts open work outside the group that waits on it.</p>
      <button type="button" className="side-row side-settings" onClick={openSettings}>
        <span className="side-label">Settings</span>
        {settingsHint && <kbd>{settingsHint}</kbd>}
      </button>
    </aside>
  )
}
