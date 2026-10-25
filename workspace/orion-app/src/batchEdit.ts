import { isWork, type AppNode, type TaskData } from './model'

/** The fields a multi-selection sets on every work item in it. */
export type BatchPatch = Partial<Pick<TaskData, 'status' | 'who'>>

/**
 * Applies one patch to every work item among `ids` in a single change, so the canvas records it as one
 * undo step. Notes and components have no status, so they stay as they are. Returns the same array
 * when nothing changes.
 */
export function patchWork(nodes: AppNode[], ids: ReadonlySet<string>, patch: BatchPatch): AppNode[] {
  let changed = false

  const next = nodes.map((node) => {
    if (!ids.has(node.id) || !isWork(node)) return node

    const data = node.data as TaskData

    if (Object.entries(patch).every(([key, value]) => data[key as keyof BatchPatch] === value)) return node

    changed = true

    return { ...node, data: { ...data, ...patch } } as AppNode
  })

  return changed ? next : nodes
}

/** The value every item shares, or `mixed` when they differ. */
export function sharedValue<T>(values: T[]): T | 'mixed' {
  return values.every((value) => value === values[0]) ? values[0] : 'mixed'
}
