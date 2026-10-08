import type { GroupStats } from './derive'
import { isCluster, type AppNode, type ClusterData } from './model'
import type { Workspaces } from './persist'

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
  colorMode: 'light' | 'dark' | 'system'
  chooseColorMode: (mode: 'light' | 'dark' | 'system') => void
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
  colorMode,
  chooseColorMode,
}: Props) {
  const clusters = nodes.filter(isCluster)
  const children = (parent: string | undefined) => clusters.filter((cluster) => cluster.parentId === parent)
  const current = workspaces.workspaces.find((item) => item.name === workspaces.active)

  const create = async () => {
    const name = window.prompt('Workspace name (lowercase letters, digits, hyphens)')?.trim()

    if (!name) return

    const label = window.prompt('Workspace label', name)?.trim()

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
          <span className="side-bar" aria-hidden="true">
            <span style={{ width: `${percent}%` }} />
          </span>
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
      <div className="side-head">
        <strong>Orion</strong>
        <button type="button" className="side-hide" onClick={hide} title="Hide the group list">
          ‹
        </button>
      </div>
      <details style={{ padding: '4px 10px', position: 'relative' }}>
        <summary style={{ cursor: 'pointer', fontSize: 13 }} title="Choose a workspace">
          {current?.label ?? workspaces.active}
        </summary>
        <div style={{ display: 'grid', gap: 4, padding: '8px 0' }}>
          {workspaces.workspaces.map((item) => (
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
      <div className="side-settings" role="group" aria-label="Color mode">
        <span className="side-settings-label">Color mode</span>
        <div className="color-mode-options">
          {(['light', 'dark', 'system'] as const).map((mode) => (
            <button key={mode} type="button" aria-pressed={colorMode === mode} onClick={() => chooseColorMode(mode)}>
              {mode[0].toUpperCase() + mode.slice(1)}
            </button>
          ))}
        </div>
      </div>
    </aside>
  )
}
