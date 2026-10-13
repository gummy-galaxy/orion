import { memo } from 'react'
import { Handle, Position, type NodeProps } from '@xyflow/react'
import { STATUS_LABEL, type GhostNode } from '../model'
import { SourceBadges } from './SourceBadges'
import { StatusIcon } from './StatusIcon'
import { useSources, useTraceRole } from '../state'

export const GhostView = memo(function GhostView({ data }: NodeProps<GhostNode>) {
  const trace = useTraceRole(data.taskId)
  const sources = useSources(data.taskId)

  return (
    <div
      className={`ghost${data.status ? ' st-' + data.status : ''} side-${data.side}${trace ? ' tr-' + trace : ''}`}
      title={`Jump to ${data.label}`}
    >
      {data.side === 'out' && <Handle type="target" position={Position.Left} isConnectable={false} />}
      <span className="ghost-where">
        {data.side === 'in' ? 'from' : 'to'} {data.where}
      </span>
      <span className="label">{data.label}</span>
      {data.status && (
        <span className="ghost-status">
          <StatusIcon status={data.status} />
          {STATUS_LABEL[data.status]}
        </span>
      )}
      <SourceBadges sources={sources} />
      {data.side === 'in' && <Handle type="source" position={Position.Right} isConnectable={false} />}
    </div>
  )
})
