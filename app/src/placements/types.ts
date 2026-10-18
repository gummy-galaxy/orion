/**
 * One more appearance of a card on the canvas, as `orion serve` stores it (#122). The card's own node is its first
 * placement; each of these shows the same card in another group. The app draws a copy as a node of its own, with the
 * placement's id and the card's data, and folds it back into a placement before saving.
 */
export type Placement = { id: string; node: string; parentId?: string; position: { x: number; y: number } }
