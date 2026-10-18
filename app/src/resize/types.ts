export type Point = { x: number; y: number }
export type Size = { width: number; height: number }
export type Box = Point & Size

/** The sides of a group a resize handle moves. A corner moves two. */
export type ResizeEdges = { left?: boolean; right?: boolean; top?: boolean; bottom?: boolean }

/** A resize in progress, driven by a group's handles. Points are on screen. */
export type GroupResize = {
  start: (groupId: string, edges: ResizeEdges, point: Point) => void
  move: (point: Point) => void
  end: () => void
}
