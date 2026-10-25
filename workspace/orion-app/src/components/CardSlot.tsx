import { Handle, Position, type Node, type NodeProps } from '@xyflow/react'
import type { TaskData } from '../model'
import { TaskView } from './TaskView'

/** A card's node data, plus whether it is away from the view and so drawn without its body. */
export type CardSlotData = TaskData & { away?: boolean }

/**
 * A card with its body, or, while it is away from the view, only the handles that edges attach to. The node keeps its
 * size and handles either way, so edges, fitting and measurement don't change when a card is drawn.
 */
export function CardSlot(props: NodeProps<Node<CardSlotData, 'task'>>) {
  if (!props.data.away) return <TaskView {...props} />

  return (
    <>
      <Handle type="target" position={Position.Left} />
      <Handle type="source" position={Position.Right} />
    </>
  )
}
