import type { SourceRef } from '../model'

/** The type a ref attaches to its card, as its adapter recorded it, or read by its kind for a ref without one. */
export function getRefType(ref: SourceRef): string | undefined {
  if (ref.type) return ref.type

  if (ref.kind === 'pull') return 'pr'

  if (ref.kind === 'branch') return 'step'

  if (ref.kind === 'issue') return /#\d+$/.test(ref.key) ? 'placeholder' : 'step'

  return undefined
}
