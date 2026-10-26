import type { Combine } from './types'

/** The selection a gesture leaves: its hits alone, added to `base`, or taken out of it. */
export function combineSelection(base: ReadonlySet<string>, hits: Iterable<string>, combine: Combine) {
  if (combine === 'replace') return new Set(hits)

  const result = new Set(base)

  for (const id of hits) {
    if (combine === 'add') result.add(id)
    else result.delete(id)
  }

  return result
}
