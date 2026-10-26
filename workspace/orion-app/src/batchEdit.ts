import { findState } from './cardTypes/findState'
import { isWork, type AppNode, type Status, type TaskData } from './model'

/** The fields a multi-selection sets on every work item in it. Its status is a meaning, which each card records as its own type's state. */
export type BatchPatch = { status?: Status; who?: TaskData['who'] }

/** The edit a batch patch makes to one card, with the status as the state the card's type declares for it. */
export function patchFor(data: TaskData, patch: BatchPatch): Partial<TaskData> {
  return patch.status === undefined ? patch : { ...patch, status: findState(data, patch.status) }
}

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
    const edit = patchFor(data, patch)

    if (Object.entries(edit).every(([key, value]) => data[key as keyof TaskData] === value)) return node

    changed = true

    return { ...node, data: { ...data, ...edit } } as AppNode
  })

  return changed ? next : nodes
}

/** The value every item shares, or `mixed` when they differ. */
export function sharedValue<T>(values: T[]): T | 'mixed' {
  return values.every((value) => value === values[0]) ? values[0] : 'mixed'
}
