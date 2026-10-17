/** Which way a link runs from the card being inspected: what it waits on, what it unblocks, or what it relates to. */
export type Direction = 'waits' | 'unblocks' | 'related'

export const DIRECTION_LABEL: Record<Direction, string> = { waits: 'Waits on', unblocks: 'Unblocks', related: 'Related' }
