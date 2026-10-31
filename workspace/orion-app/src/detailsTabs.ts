/** The views the details panel switches between. */
export type DetailsTab = 'details' | 'table'

/** The details panel's tabs, in the order they show. */
export const DETAILS_TABS: { id: DetailsTab; label: string }[] = [
  { id: 'details', label: 'Details' },
  { id: 'table', label: 'Table' },
]
