import type { Link } from './model'

/** Names a link after its pair and kind the way the CLI does. */
const linkId = (from: string, to: string, kind: Link['kind']) => (kind === 'blocks' ? `${from}>${to}` : `${from}~${to}`)

/**
 * Moves one or both ends of a link, keeping its kind and label. A link moved by hand is no longer one
 * Orion derived, so it drops its origin. Returns the same array when nothing changes: the link is
 * missing, it would join a card to itself, its ends stay put, or another link already joins the pair.
 */
export function reconnectLink(links: Link[], id: string, ends: { from?: string; to?: string }): Link[] {
  const link = links.find((candidate) => candidate.id === id)

  if (!link) return links

  const from = ends.from ?? link.from
  const to = ends.to ?? link.to

  if (from === to || (from === link.from && to === link.to)) return links

  const taken = links.some((other) => other !== link && ((other.from === from && other.to === to) || (other.from === to && other.to === from)))

  if (taken) return links

  const { origin: _, ...kept } = link

  return links.map((candidate) => (candidate === link ? { ...kept, id: linkId(from, to, link.kind), from, to } : candidate))
}
