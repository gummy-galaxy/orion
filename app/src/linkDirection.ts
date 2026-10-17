import { isComponent, type AppNode } from './model'

/** Which way a link runs from the card being inspected: what it waits on, what it unblocks, or what it relates to. */
export type Direction = 'waits' | 'unblocks' | 'related'

export const DIRECTION_LABEL: Record<Direction, string> = { waits: 'Waits on', unblocks: 'Unblocks', related: 'Related' }

/** Components aren't work, so their links read as what comes in and goes out. */
export const COMPONENT_DIRECTION_LABEL: Record<Direction, string> = { waits: 'Incoming', unblocks: 'Outgoing', related: 'Related' }

/** The direction labels for the card being inspected. */
export const directionLabels = (node: AppNode): Record<Direction, string> => (isComponent(node) ? COMPONENT_DIRECTION_LABEL : DIRECTION_LABEL)
