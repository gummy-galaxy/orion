/** The approaches the spike compares, in the order the switcher shows them. */
export const APPROACHES = [
  { id: 'curves', label: 'Curves (today)' },
  { id: 'libavoid', label: 'libavoid' },
  { id: 'lanes', label: 'Lanes (ours)' },
  { id: 'bundles', label: 'Bundles' },
  { id: 'plugs', label: 'Plugs' },
  { id: 'plugBundles', label: 'Plugs + bundles' },
] as const

export type Approach = (typeof APPROACHES)[number]['id']

/** Canvas sizes, by link count. */
export const SIZES = [90, 200, 1000] as const

export type Size = (typeof SIZES)[number]

/** libavoid freezes the page for seconds past this many links, so the story won't run it on bigger canvases. */
export const AVOID_LIMIT = 90

/** Links longer than this, in canvas pixels, become plugs. About the width of a group, so most links inside one stay whole. */
export const PLUG_THRESHOLD = 1000

export const THRESHOLD_RANGE = { min: 200, max: 4000, step: 100 }
