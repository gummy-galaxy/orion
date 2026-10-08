import { memo, useContext } from 'react'
import { Handle, Position, type NodeProps } from '@xyflow/react'
import { ActionsContext } from '../derive'
import type { ClusterNode } from '../model'
import { SourceBadges } from './SourceBadges'
import { useCollapsed, useGroupStats, useMarked, useSources, useTraceRole } from '../state'
import { Ring } from './Ring'

export const ClusterView = memo(function ClusterView({ id, data }: NodeProps<ClusterNode>) {
  const actions = useContext(ActionsContext)!
  const stats = useGroupStats(id)
  const collapsed = useCollapsed(id)
  const trace = useTraceRole(id)
  const attention = useMarked(id)
  const sources = useSources(id)
  return (
    <div className={`cluster${collapsed ? ' is-collapsed' : ''}${trace ? ' tr-' + trace : ''}`}>
      <Handle type="target" position={Position.Left} isConnectable={false} />
      {collapsed ? (
        <div className="pop drag">
          <span className="pop-anchor" />
          <div className="pop-place">
            <div className={`bubble${attention ? ' attn' : ''}`}>
              <div className="bubble-title">
                <Ring done={stats.done} total={stats.total} size={16} />
                <strong>{data.label}</strong>
              </div>
              <span className="bubble-stats">
                {stats.done}/{stats.total} done · {stats.ready} ready · {stats.blocked} blocked
              </span>
              {stats.outside > 0 && <span className="bubble-lev">unblocks {stats.outside} outside</span>}
              <SourceBadges sources={sources} inBubble />
            </div>
          </div>
        </div>
      ) : (
        <div className="cluster-head drag" title="Double-click to open">
          <Ring done={stats.done} total={stats.total} />
          <strong>{data.label}</strong>
          <span className="count">
            {stats.done}/{stats.total}
          </span>
          {stats.outside > 0 && <span className="lev-inline">unblocks {stats.outside} outside</span>}
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
      {!collapsed && <SourceBadges sources={sources} />}
      <Handle type="source" position={Position.Right} isConnectable={false} />
    </div>
  )
})
