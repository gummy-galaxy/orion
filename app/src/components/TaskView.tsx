import { memo } from 'react'
import { Handle, Position, useStore, type NodeProps } from '@xyflow/react'
import type { TaskNode } from '../model'
import { useAtomValue } from 'jotai'
import { useCardView, useMarked, useTraceRole, skinAtom, skinStore } from '../state'
import { CardBody } from './CardBody'
import { FarTag } from './FarTag'

/** Zoom below which a card's details sit in a tag over its body that keeps one on-screen size. */
const FAR_ZOOM = 0.3

// Memoized because React Flow re-renders every node wrapper whenever the canvas passes new handlers.
export const TaskView = memo(function TaskView({ id, data }: NodeProps<TaskNode>) {
  const far = useStore((state) => state.transform[2] < FAR_ZOOM)
  const view = useCardView(id, data)
  const trace = useTraceRole(id)
  const attention = useMarked(id)
  const skin = useAtomValue(skinAtom, { store: skinStore })
  const className =
    view.kind === 'note'
      ? `card skin-${skin} note${trace ? ' tr-' + trace : ''}`
      : `card skin-${skin} st-${view.status}${view.kind === 'placeholder' ? ' placeholder' : ''}${view.kind === 'gate' ? ' gate' : ''}${trace ? ' tr-' + trace : ''}${attention ? ' attn' : ''}`
  const body = <CardBody view={view} />

  return (
    <div className={className}>
      <Handle type="target" position={Position.Left} />
      {far ? <FarTag className={className}>{body}</FarTag> : body}
      <Handle type="source" position={Position.Right} />
    </div>
  )
})
