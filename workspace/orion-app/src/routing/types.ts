/** A card or group on the canvas, in absolute canvas coordinates. */
export type Box = { id: string; x: number; y: number; width: number; height: number }

export type Point = { x: number; y: number }

/** A card, with the innermost group that holds it. */
export type SceneCard = Box & { group: string | null }

/** What a router sees: every card and group at its current position, and the links between cards. */
export type Scene = {
  cards: SceneCard[]
  groups: Box[]
  links: { id: string; from: string; to: string }[]
}

/**
 * One line to draw. Most stand for one link, but a bundle draws a shared trunk and branches, so `source` and `target`
 * only anchor the line in React Flow and `arrow` says whether it ends in an arrowhead.
 */
export type RoutedLine = {
  id: string
  source: string
  target: string
  d: string
  arrow: boolean
  width?: number
  label?: string
  labelAt?: Point
  plug?: Plug
}

/**
 * A small copy of the card at the far end of a link too long to draw, where its stub stops. `at` is the plug's top-left
 * corner, `owner` is the card the stub leaves, `port` is where the stub meets it, and `more` counts the other links folded into it when a card
 * has more far links than plugs fit beside it.
 */
export type Plug = { at: Point; owner: string; port: Point; side: 'out' | 'in'; card: string; links: string[]; more: number }

export type Routing = {
  lines: RoutedLine[]
  /** Links the router couldn't keep off cards, drawn anyway. */
  fallbacks: number
  /** Links drawn as stubs and plugs instead of in full. */
  stubbed?: number
}
