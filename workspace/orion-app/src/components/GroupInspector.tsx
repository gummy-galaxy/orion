import type { GroupStats } from '../derive'
import type { AppNode, ClusterData } from '../model'
import type { StyleChange } from '../style'
import { CoverSettings } from './CoverSettings'
import { GroupArrange } from './GroupArrange'
import { GroupFacts } from './GroupFacts'
import { HeaderSettings } from './HeaderSettings'
import { TintSelect } from './TintSelect'

/** A group's name, progress, and styling, for a selected group or the one that's open. */
export function GroupInspector({
  node,
  stats,
  workspace,
  focus,
  doneEditing,
  update,
  arrange,
  changeStyle,
  reflow,
  open,
  ungroup,
}: {
  node: AppNode
  stats: GroupStats | undefined
  workspace: string
  focus: boolean
  doneEditing: () => void
  update: (id: string, patch: Partial<ClusterData>) => void
  arrange: (patch: Pick<ClusterData, 'arrange'>) => void
  changeStyle: (change: StyleChange) => void
  reflow: () => void
  /** Left out for the open group, which is already open. */
  open?: () => void
  /** Left out for the open group, which can't release itself from inside. */
  ungroup?: () => void
}) {
  const data = node.data as ClusterData

  return (
    <div className="insp">
      <label htmlFor="g-label">Group name</label>
      <input
        id="g-label"
        value={data.label}
        autoFocus={focus}
        onFocus={(event) => focus && event.target.select()}
        onBlur={doneEditing}
        onKeyDown={(event) => event.key === 'Enter' && event.currentTarget.blur()}
        onChange={(event) => update(node.id, { label: event.target.value })}
      />
      {data.blurb && <p className="blurb">{data.blurb}</p>}
      <GroupFacts stats={stats} />
      <label htmlFor="g-color">Color</label>
      <TintSelect
        id="g-color"
        value={data.color}
        inherit={node.parentId ? "Its group's" : 'None'}
        change={(color) => update(node.id, { color })}
      />
      <GroupArrange data={data} change={arrange} />
      <CoverSettings title="Cover and background" workspace={workspace} current={data} change={changeStyle} />
      <HeaderSettings title="Header" value={data.header} change={(header) => changeStyle({ header })} />
      <div className="row">
        {open && (
          <button type="button" className="btn primary" onClick={open}>
            Open
          </button>
        )}
        {data.arrange !== 'custom' && (
          <button type="button" className="btn" onClick={reflow}>
            Reflow
          </button>
        )}
        {ungroup && (
          <button type="button" className="btn" onClick={ungroup}>
            Ungroup <kbd>⇧⌘G</kbd>
          </button>
        )}
      </div>
    </div>
  )
}
