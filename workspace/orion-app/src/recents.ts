/** A command or a card or group the palette ran or jumped to. Commands are matched by id, nodes by id too. */
export type Recent = { kind: 'command' | 'node'; id: string }

/** About how many entries the palette keeps per workspace. */
export const RECENT_LIMIT = 50

/** How far a recently used match moves up among matches of similar quality. Newer entries get a little more. */
export const RECENT_BOOST = 100

/** The data-folder preference that holds one workspace's recents. */
export const recentsKey = (workspace: string) => `palette-recents:${workspace}`

export const recentKey = (recent: Recent) => `${recent.kind}:${recent.id}`

const isRecent = (value: unknown): value is Recent => {
  if (typeof value !== 'object' || value === null) return false

  const { kind, id } = value as Partial<Record<keyof Recent, unknown>>

  return (kind === 'command' || kind === 'node') && typeof id === 'string'
}

/** Reads the saved list, skipping anything malformed so a damaged file can't break the palette. */
export function readRecents(value: unknown): Recent[] {
  if (!Array.isArray(value)) return []

  return value.filter(isRecent).slice(0, RECENT_LIMIT)
}

/** Moves `entry` to the front, dropping its older copy, and keeps the newest entries. */
export function addRecent(recents: Recent[], entry: Recent): Recent[] {
  const key = recentKey(entry)

  return [entry, ...recents.filter((recent) => recentKey(recent) !== key)].slice(0, RECENT_LIMIT)
}

/** Forgets cards and groups that no longer exist. Commands stay, since they come and go with the canvas's state. */
export function keepExistingNodes(recents: Recent[], nodeIds: ReadonlySet<string>): Recent[] {
  return recents.filter((recent) => recent.kind === 'command' || nodeIds.has(recent.id))
}
