/**
 * Card types declare these four fields like any other. Other fields keep their values under `fields`, but these stay
 * directly on the card's data, where cards stored them before types existed. Each has its own input in the details
 * panel, rather than one `TypeFields` draws.
 */
export const CORE_FIELDS: ReadonlySet<string> = new Set(['who', 'repo', 'shape', 'color'])
