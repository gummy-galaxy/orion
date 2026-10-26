import type { SourceRef } from '../model'

/**
 * Whether two refs name the same work. Refs of one kind match by their sources' stable ids when both have one, since a
 * key changes when what it names moves. Otherwise they match by case-insensitive key.
 */
export function isSameRef(a: SourceRef, b: SourceRef): boolean {
  if (a.kind !== b.kind) return false

  if (a.id !== undefined && b.id !== undefined) return a.id === b.id

  return a.key.toLowerCase() === b.key.toLowerCase()
}
