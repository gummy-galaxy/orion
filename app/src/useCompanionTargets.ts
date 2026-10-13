import { useStoreApi } from '@xyflow/react'
import { useStore } from 'jotai'
import { useCallback } from 'react'
import { describeCard, type Hint, type PerchTarget } from './companion'
import { GROUP_HEADER_HEIGHT, GROUP_PADDING, TASK_HEIGHT, isNote } from './model'
import { collapsedAtom, nodesAtom, workAtom } from './state'

/** How far into an open group, in canvas units, its top row of cards starts. */
const TOP_ROW_DEPTH = GROUP_HEADER_HEIGHT + GROUP_PADDING + TASK_HEIGHT

/**
 * What the companion can perch on and what it says there, read from React Flow's measured nodes and the derived work
 * on demand, so the canvas never redraws for it and it never measures the page.
 */
export function useCompanionTargets() {
  const flow = useStoreApi()
  const store = useStore()

  const targets = useCallback((): PerchTarget[] => {
    const { nodeLookup, transform } = flow.getState()
    const [translateX, translateY, zoom] = transform
    const collapsed = store.get(collapsedAtom)
    const shown: PerchTarget[] = []

    for (const node of nodeLookup.values()) {
      if (node.hidden) continue

      // Cards and folded groups; an open group's frame would always be nearest whatever is inside it.
      const perchable = (node.type === 'task' && node.data.itemKind !== 'note') || (node.type === 'cluster' && collapsed.has(node.id))

      if (!perchable) continue

      const { x, y } = node.internals.positionAbsolute
      const width = node.measured.width ?? node.width ?? 0
      const height = node.measured.height ?? node.height ?? 0
      const left = x * zoom + translateX
      const top = y * zoom + translateY
      const parent = node.parentId ? nodeLookup.get(node.parentId) : undefined
      // A card in the top row of an open group perches above the group's header rather than on it.
      const parentY = parent?.type === 'cluster' && !collapsed.has(parent.id) ? parent.internals.positionAbsolute.y : undefined
      const underHeader = parentY !== undefined && y - parentY < TOP_ROW_DEPTH

      shown.push({
        id: node.id,
        rect: { left, top, right: left + width * zoom, bottom: top + height * zoom },
        top: underHeader ? parentY * zoom + translateY : undefined,
      })
    }

    return shown
  }, [flow, store])

  const describe = useCallback(
    (id: string): Hint | null => {
      const node = store.get(nodesAtom).find((other) => other.id === id)

      if (!node || isNote(node)) return null

      const work = store.get(workAtom)

      if (node.type === 'cluster') {
        const stats = work.groups.get(id)
        const progress = stats?.total ? ` · ${stats.done}/${stats.total}` : ''

        return { text: `${node.data.label}${progress}`, mood: '' }
      }

      if (node.type !== 'task') return null

      return describeCard(work.status.get(id) ?? 'ready', node.data.who)
    },
    [store],
  )

  return { targets, describe }
}
