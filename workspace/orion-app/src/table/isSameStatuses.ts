import type { ViewStatus } from '../model'

/** Whether two status lookups give every card the same status. */
export function isSameStatuses(a: Map<string, ViewStatus>, b: Map<string, ViewStatus>): boolean {
  if (a.size !== b.size) return false

  for (const [id, status] of a) if (b.get(id) !== status) return false

  return true
}
