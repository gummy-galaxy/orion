import type { ItemKind, ViewStatus } from '../model'

/** One card as the Table tab lists it. */
export type TableRow = {
  id: string
  label: string
  kind: ItemKind
  /** Undefined for notes and components, which aren't work. */
  status?: ViewStatus
  /** The label of the group that directly holds the card, if any. */
  group?: string
  /** The card's main source ref, such as its pull request. */
  ref?: string
}

/** The first row a scrolled list draws and the one after its last. */
export type RowRange = { start: number; end: number }
