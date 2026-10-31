/** How far past the visible canvas, in screen pixels, a card still counts as near enough to draw. */
export const DRAW_MARGIN_PX = 400
/** Cards given their bodies per frame, so a burst of cards never mounts in one frame. */
export const DRAW_BATCH = 40
/** Quiet time after the view stops moving before the queue is re-sorted around its final center. */
export const SETTLE_MS = 150

export type Point = { x: number; y: number }
export type Rect = { x: number; y: number; width: number; height: number }
export type DrawCard = Rect & { id: string }
/** The view in flow coordinates: the box it covers with its margin, and the point at its middle. */
export type DrawView = { box: Rect; center: Point }

/** The view for a React Flow transform, or null before the canvas has a size. */
export function drawViewOf(transform: [number, number, number], width: number, height: number): DrawView | null {
  const [tx, ty, zoom] = transform

  if (!width || !height || !(zoom > 0)) return null

  const margin = DRAW_MARGIN_PX / zoom

  return {
    box: {
      x: -tx / zoom - margin,
      y: -ty / zoom - margin,
      width: width / zoom + 2 * margin,
      height: height / zoom + 2 * margin,
    },
    center: { x: (width / 2 - tx) / zoom, y: (height / 2 - ty) / zoom },
  }
}

function overlaps(card: Rect, box: Rect): boolean {
  return (
    card.x < box.x + box.width &&
    card.x + card.width > box.x &&
    card.y < box.y + box.height &&
    card.y + card.height > box.y
  )
}

/**
 * Decides which cards get their bodies. Cards are queued nearest the view's center first and mounted in batches,
 * and a card that leaves the margin is dropped at once. The React Flow node stays either way, so edges, fitting and
 * measurement don't depend on what's drawn.
 */
export class CardDraw {
  /** The ids whose bodies are mounted now. */
  readonly drawn = new Set<string>()
  private cards = new Map<string, DrawCard>()
  private queue: string[] = []
  private view: DrawView | null = null

  get pending(): boolean {
    return this.queue.length > 0
  }

  /** Takes the latest cards and view. Returns true when the drawn set changed. */
  update(cards: DrawCard[], view: DrawView | null): boolean {
    const wanted = new Set<string>()

    this.cards = new Map(cards.map((card) => [card.id, card]))
    this.view = view

    if (view) for (const card of cards) if (overlaps(card, view.box)) wanted.add(card.id)

    let changed = false

    for (const id of [...this.drawn]) {
      if (wanted.has(id)) continue

      this.drawn.delete(id)
      changed = true
    }

    this.queue = this.queue.filter((id) => wanted.has(id) && !this.drawn.has(id))

    const queued = new Set(this.queue)
    const arrivals = cards.filter((card) => wanted.has(card.id) && !this.drawn.has(card.id) && !queued.has(card.id))

    this.queue.push(...this.nearest(arrivals.map((card) => card.id)))

    return changed
  }

  /** Gives the next batch of queued cards their bodies. Returns true when the drawn set changed. */
  step(): boolean {
    const batch = this.queue.splice(0, DRAW_BATCH)

    for (const id of batch) this.drawn.add(id)

    return batch.length > 0
  }

  /** Re-sorts what's still queued around the view's current center, once the view has settled. */
  settle(): void {
    this.queue = this.nearest(this.queue)
  }

  private nearest(ids: string[]): string[] {
    const center = this.view?.center

    if (!center) return ids

    const distance = (id: string) => {
      const card = this.cards.get(id)

      if (!card) return Infinity

      const dx = card.x + card.width / 2 - center.x
      const dy = card.y + card.height / 2 - center.y

      return dx * dx + dy * dy
    }

    return ids
      .map((id) => ({ id, distance: distance(id) }))
      .sort((a, b) => a.distance - b.distance)
      .map((entry) => entry.id)
  }
}
