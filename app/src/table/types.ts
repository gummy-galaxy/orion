import type { ItemKind, SourceRef, Status, ViewStatus, Who } from '../model'

/** One card as the database view lists it: its own fields plus what the graph and its sources say about it. */
export type TableRow = {
  id: string
  label: string
  kind: ItemKind
  /** Derived, as the canvas shows it. Components have none. */
  status?: ViewStatus
  recordedStatus: Status
  /** The group it sits in directly, if any. */
  groupId?: string
  /** The labels of every group it sits in, outermost first. */
  groups: string[]
  /** Its groups below the open one, such as "Docs › Reference", or empty when it sits in the open group itself. */
  groupPath: string
  repo?: string
  note?: string
  refs: SourceRef[]
  pr?: string
  draft?: string
  snoozed: boolean
  who?: Who
  /** A source's priority, such as a Jira issue's. Orion has no priority of its own. */
  priority?: string
  /** Lines changed in its pull request. */
  lines?: number
}

export type SortKey = 'label' | 'status' | 'kind' | 'group' | 'refs' | 'priority' | 'size' | 'who'
export type Sort = { key: SortKey; direction: 'asc' | 'desc' }
