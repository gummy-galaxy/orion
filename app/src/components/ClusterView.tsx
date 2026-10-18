import { memo, useContext } from 'react'
import { useAtomValue } from 'jotai'
import { Handle, Position, useStore, type NodeProps } from '@xyflow/react'
import { ActionsContext } from '../derive'
import { GROUP_HEADER_BAND, GROUP_HEADER_HEIGHT, type ClusterNode } from '../model'
import { SourceBadges } from './SourceBadges'
import {
  useCollapsed,
  useGroupParts,
  useGroupStats,
  useIsDropTarget,
  useIsEmptyGroup,
  useMarked,
  useShowsResizeHandles,
  useSources,
  useTint,
  useTraceRole,
  workspaceAtom,
} from '../state'
import { HEADER_MIN_ZOOM, groupLayers, headerText } from '../style'
import { CoverImage } from './CoverImage'
import { Markdown } from './Markdown'
import { Ring } from './Ring'
import { FoldPreview } from './FoldPreview'
import { GroupResizeHandles } from './GroupResizeHandles'

export const ClusterView = memo(function ClusterView({ id, data, width, height }: NodeProps<ClusterNode>) {
  const actions = useContext(ActionsContext)!
  const compact = useStore((state) => (width ?? 320) * state.transform[2] < 180 || (height ?? 200) * state.transform[2] < 80)
  const tiny = useStore((state) => (width ?? 320) * state.transform[2] < 120 || (height ?? 200) * state.transform[2] < 60)
  const stats = useGroupStats(id)
  const collapsed = useCollapsed(id)
  const trace = useTraceRole(id)
  const attention = useMarked(id)
  const sources = useSources(id)
  const tint = useTint(id)
  // Groups that hold no work, like the boundaries of a system diagram, have no progress to show.
  const hasWork = stats.total > 0
  const parts = useGroupParts(id)
  const isEmpty = useIsEmptyGroup(id)
  const isDropTarget = useIsDropTarget(id)
  const showsResizeHandles = useShowsResizeHandles(id)
  const workspace = useAtomValue(workspaceAtom)
  const headerFolded = useStore((state) => state.transform[2] < HEADER_MIN_ZOOM)
  const layers = groupLayers(data, collapsed)
  // A folded group, or one zoomed too far out to read, shows no header; its band stays reserved so nothing moves.
  const header = collapsed || headerFolded ? undefined : headerText(data.header)

  return (
    <div
      className={`cluster${tint ? ' tint-' + tint : ''}${collapsed ? ' is-collapsed' : ''}${trace ? ' tr-' + trace : ''}${attention ? ' attn' : ''}${isDropTarget ? ' is-drop-target' : ''}`}
      style={layers.color ? { background: layers.color } : undefined}
    >
      <Handle type="target" position={Position.Left} isConnectable={false} />
      {layers.backdrop && (
        <div className="cluster-backdrop">
          <CoverImage workspace={workspace} asset={layers.backdrop} className="cluster-backdrop-image" />
        </div>
      )}
      {layers.cover && (
        <div className="cluster-cover">
          <CoverImage workspace={workspace} asset={layers.cover} className="cluster-cover-image" />
        </div>
      )}
      {collapsed ? (
        <>
          <FoldPreview id={id} width={width ?? 320} height={height ?? 200} />
          <div className={`cluster-card drag${compact ? ' is-compact' : ''}${tiny ? ' is-tiny' : ''}`} title="Double-click to open">
            {/* The text wraps into all the room the group has and clips only at its edge. */}
            <div className="cluster-card-body">
              <div className="cluster-card-title">
                {hasWork && <Ring done={stats.done} total={stats.total} size={16} />}
                <strong>{data.label}</strong>
              </div>
              {hasWork ? (
                <span className="cluster-card-stats">
                  <span>
                    {stats.done}/{stats.total} done
                  </span>
                  <span>{stats.ready} ready</span>
                  <span>{stats.blocked} blocked</span>
                </span>
              ) : // A folded diagram group lists what it holds, so the system still reads from far out.
              parts.length > 0 ? (
                <ul className="cluster-card-parts">
                  {parts.map((part, i) => (
                    <li key={i}>{part}</li>
                  ))}
                </ul>
              ) : (
                isEmpty && (
                  <span className="cluster-card-stats">
                    <span>Empty group</span>
                  </span>
                )
              )}
            </div>
            {stats.outside > 0 && <span className={`lev cluster-card-lev${stats.outside >= 4 ? ' big' : ''}`}>unblocks {stats.outside}</span>}
            <SourceBadges sources={sources} />
          </div>
        </>
      ) : (
        <div className="cluster-head drag" title="Double-click to open">
          {hasWork && <Ring done={stats.done} total={stats.total} />}
          <strong>{data.label}</strong>
          {hasWork && (
            <span className="count">
              {stats.done}/{stats.total}
            </span>
          )}
          {stats.outside > 0 && <span className="lev-inline">unblocks {stats.outside}</span>}
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
      {header && (
        <div className="cluster-header nodrag" style={{ top: GROUP_HEADER_HEIGHT, height: GROUP_HEADER_BAND }}>
          <Markdown source={header} layout />
        </div>
      )}
      {!collapsed && isEmpty && <span className="cluster-empty">Empty group</span>}
      {!collapsed && <SourceBadges sources={sources} />}
      {!collapsed && showsResizeHandles && <GroupResizeHandles id={id} />}
      <Handle type="source" position={Position.Right} isConnectable={false} />
    </div>
  )
})
