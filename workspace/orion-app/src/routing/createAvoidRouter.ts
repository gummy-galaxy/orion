import { AvoidLib, type Avoid } from 'libavoid-js'
import { sourcePort, targetPort } from './ports'
import { roundedPath } from './roundedPath'
import type { Point, Routing, Scene, SceneCard } from './types'

/** Pin classes: every card has one pin out on its right side and one in on its left, like React Flow's handles. */
const OUT = 1
const IN = 2
/** libavoid's direction flags for a pin's side. */
const RIGHT = 8
const LEFT = 4
/** Clearance libavoid keeps around cards. */
const BUFFER = 10
/** Without pins, a link starts and ends this far out from its handle, just past the clearance. */
const STUB = BUFFER + 2

/** Loads libavoid's WebAssembly once. The browser passes the file's URL; Node finds it beside the package. */
export async function loadAvoid(wasmUrl?: string): Promise<Avoid> {
  if (!AvoidLib.avoidLib) await AvoidLib.load(wasmUrl)

  return AvoidLib.getInstance()
}

type Shape = { shape: InstanceType<Avoid['ShapeRef']>; card: SceneCard }
type Connection = { id: string; from: string; to: string; connection: InstanceType<Avoid['ConnRef']> }
type Built = { router: InstanceType<Avoid['Router']>; shapes: Map<string, Shape>; connections: Connection[]; key: string }

/** A key that changes when cards or links come or go, which forces a rebuild instead of moving shapes. */
const structureOf = (scene: Scene) => scene.cards.map((card) => card.id).join(',') + '|' + scene.links.map((link) => link.id).join(',')

export type AvoidOptions = {
  /**
   * Attach links to pins on the cards' sides, which is how libavoid keeps a line leaving right and arriving left.
   * Pins cost about ten times as much as free endpoints, so without them a link ends at a point just outside each
   * handle and a short stub joins it to the card.
   */
  pins?: boolean
}

/**
 * Routes with libavoid: orthogonal connectors around every card, with parallel segments nudged apart. It keeps its
 * router between calls, so a drag only moves the shapes that moved, but libavoid still reroutes every connector.
 */
export function createAvoidRouter(Avoid: Avoid, { pins = false }: AvoidOptions = {}) {
  let built: Built | null = null

  const rectangle = (card: SceneCard) =>
    new Avoid.Rectangle(new Avoid.Point(card.x, card.y), new Avoid.Point(card.x + card.width, card.y + card.height))

  const leaving = (card: SceneCard) => {
    const port = sourcePort(card)

    return pins ? new Avoid.ConnEnd(built!.shapes.get(card.id)!.shape, OUT) : new Avoid.ConnEnd(new Avoid.Point(port.x + STUB, port.y))
  }

  const arriving = (card: SceneCard) => {
    const port = targetPort(card)

    return pins ? new Avoid.ConnEnd(built!.shapes.get(card.id)!.shape, IN) : new Avoid.ConnEnd(new Avoid.Point(port.x - STUB, port.y))
  }

  const build = (scene: Scene) => {
    const router = new Avoid.Router(Avoid.RouterFlag.OrthogonalRouting.value)

    router.setRoutingParameter(Avoid.RoutingParameter.shapeBufferDistance, BUFFER)
    router.setRoutingParameter(Avoid.RoutingParameter.idealNudgingDistance, 5)
    router.setRoutingOption(Avoid.RoutingOption.nudgeOrthogonalSegmentsConnectedToShapes, true)
    router.setRoutingOption(Avoid.RoutingOption.nudgeSharedPathsWithCommonEndPoint, true)
    built = { router, shapes: new Map(), connections: [], key: structureOf(scene) }

    for (const card of scene.cards) {
      const shape = new Avoid.ShapeRef(router, rectangle(card))

      if (pins) {
        // Pins are exclusive by default, which lets only one link use each; cards have many links per side.
        new Avoid.ShapeConnectionPin(shape, OUT, 1, 0.5, true, 0, RIGHT).setExclusive(false)
        new Avoid.ShapeConnectionPin(shape, IN, 0, 0.5, true, 0, LEFT).setExclusive(false)
      }

      built.shapes.set(card.id, { shape, card })
    }

    for (const link of scene.links) {
      const from = built.shapes.get(link.from)!.card
      const to = built.shapes.get(link.to)!.card

      built.connections.push({ ...link, connection: new Avoid.ConnRef(router, leaving(from), arriving(to)) })
    }
  }

  const route = (scene: Scene): Routing => {
    if (!built || built.key !== structureOf(scene)) {
      built?.router.delete()
      build(scene)
    } else {
      const moved = new Set<string>()

      for (const card of scene.cards) {
        const known = built.shapes.get(card.id)!

        if (known.card.width !== card.width || known.card.height !== card.height) built.router.moveShape_poly(known.shape, rectangle(card))
        else if (known.card.x !== card.x || known.card.y !== card.y)
          built.router.moveShape_delta(known.shape, card.x - known.card.x, card.y - known.card.y)
        else continue

        known.card = card
        moved.add(card.id)
      }

      // Free endpoints don't follow their shape, so links on a moved card get new ones.
      if (!pins) {
        for (const { from, to, connection } of built.connections) {
          if (moved.has(from)) connection.setSourceEndpoint(leaving(built.shapes.get(from)!.card))

          if (moved.has(to)) connection.setDestEndpoint(arriving(built.shapes.get(to)!.card))
        }
      }
    }

    const { router, shapes, connections } = built!

    router.processTransaction()

    const lines = connections.map(({ id, from, to, connection }) => {
      const points: Point[] = []
      // The bundled typings predate the embind build, which exposes the points as a `ps` vector.
      const polyline = connection.displayRoute() as unknown as { size(): number; ps: { get(i: number): Point } }

      for (let i = 0; i < polyline.size(); i++) {
        const point = polyline.ps.get(i)

        points.push({ x: point.x, y: point.y })
      }

      if (!pins) {
        points.unshift(sourcePort(shapes.get(from)!.card))
        points.push(targetPort(shapes.get(to)!.card))
      }

      return { id, source: from, target: to, d: roundedPath(points), arrow: true }
    })

    return { lines, fallbacks: 0 }
  }

  const dispose = () => {
    built?.router.delete()
    built = null
  }

  return { route, dispose }
}
