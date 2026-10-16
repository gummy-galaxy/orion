import { memo, useContext } from 'react'
import { useAtomValue } from 'jotai'
import { Handle, Position, useStore, type NodeProps } from '@xyflow/react'
import { ActionsContext } from '../derive'
import type { ClusterNode } from '../model'
import { SourceBadges } from './SourceBadges'
import { useCollapsed, useIsDropTarget, useGroupStats, useMarked, useSources, useTraceRole, workspaceAtom } from '../state'
import { groupLayers } from '../style'
import { CoverImage } from './CoverImage'
import { Ring } from './Ring'
import { FoldPreview } from './FoldPreview'

export const ClusterView = memo(function ClusterView({ id, data, width, height }: NodeProps<ClusterNode>) {
  const actions = useContext(ActionsContext)!
  const compact = useStore((state) => (width ?? 320) * state.transform[2] < 180 || (height ?? 200) * state.transform[2] < 80)
  const tiny = useStore((state) => (width ?? 320) * state.transform[2] < 120 || (height ?? 200) * state.transform[2] < 60)
  const stats = useGroupStats(id)
  const collapsed = useCollapsed(id)
  const trace = useTraceRole(id)
  const attention = useMarked(id)
  const sources = useSources(id)
  const isDropTarget = useIsDropTarget(id)
  const workspace = useAtomValue(workspaceAtom)
  const layers = groupLayers(data, collapsed)

  return (
    <div
      className={`cluster${collapsed ? ' is-collapsed' : ''}${trace ? ' tr-' + trace : ''}${attention ? ' attn' : ''}${isDropTarget ? ' is-drop-target' : ''}`}
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
            <div className="cluster-card-title">
              <Ring done={stats.done} total={stats.total} size={16} />
              <strong>{data.label}</strong>
            </div>
            <span className="cluster-card-stats">
              {stats.total === 0 ? (
                <span>Empty group</span>
              ) : (
                <>
                  <span>
                    {stats.done}/{stats.total} done
                  </span>
                  <span>{stats.ready} ready</span>
                  <span>{stats.blocked} blocked</span>
                </>
              )}
            </span>
            {stats.outside > 0 && <span className={`lev cluster-card-lev${stats.outside >= 4 ? ' big' : ''}`}>unblocks {stats.outside}</span>}
            <SourceBadges sources={sources} />
          </div>
        </>
      ) : (
        <div className="cluster-head drag" title="Double-click to open">
          <Ring done={stats.done} total={stats.total} />
          <strong>{data.label}</strong>
          <span className="count">
            {stats.done}/{stats.total}
          </span>
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
      {!collapsed && stats.total === 0 && <span className="cluster-empty">Empty group</span>}
      {!collapsed && <SourceBadges sources={sources} />}
      <Handle type="source" position={Position.Right} isConnectable={false} />
    </div>
  )
})
