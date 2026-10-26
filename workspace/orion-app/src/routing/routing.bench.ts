import { test } from 'vitest'
import { buildMessyCanvas } from './buildMessyCanvas'
import { createAvoidRouter, loadAvoid } from './createAvoidRouter'
import { createLaneRouter } from './createLaneRouter'
import { routeBundles } from './routeBundles'
import { routeCurves } from './routeCurves'
import { sceneOf } from './sceneOf'
import type { Scene } from './types'

const SIZES = [90, 200, 1000]
const RUN = { time: 400, iterations: 12, warmupTime: 100 }

/** The scene with one card nudged sideways, alternating each call, the way a drag moves it a frame at a time. */
function dragging(scene: Scene) {
  const index = Math.floor(scene.cards.length / 2)
  let step = 0

  return () => {
    step++

    return { ...scene, cards: scene.cards.map((card, i) => (i === index ? { ...card, x: card.x + (step % 2 ? 8 : 0) } : card)) }
  }
}

for (const links of SIZES) {
  const { nodes, links: canvasLinks } = buildMessyCanvas({ links })
  const scene = sceneOf(nodes, canvasLinks)

  test(`${links} links`, async ({ bench }) => {
    await bench('curves', () => routeCurves(scene)).run(RUN)
    await bench('bundles', () => routeBundles(scene)).run(RUN)
    await bench('lanes, from scratch', () => createLaneRouter().route(scene)).run(RUN)

    const lanes = createLaneRouter()
    const lanesFrame = dragging(scene)

    lanes.route(scene)
    await bench('lanes, one card dragged', () => lanes.route(lanesFrame())).run(RUN)
  })
}

// libavoid takes seconds where the others take milliseconds, so it runs once per size, and only up to 200 links.
const AVOID_SIZES = (process.env.AVOID_SIZES ?? '90,200').split(',').map(Number).filter(Boolean)

for (const links of AVOID_SIZES) {
  const { nodes, links: canvasLinks } = buildMessyCanvas({ links })
  const scene = sceneOf(nodes, canvasLinks)

  for (const pins of [false, true]) {
    test(`${links} links, libavoid${pins ? ' with pins' : ''}`, { timeout: 30 * 60_000 }, async ({ bench }) => {
      const Avoid = await loadAvoid()
      const once = { time: 0, iterations: 1, warmupTime: 0, warmupIterations: 0 }
      const router = createAvoidRouter(Avoid, { pins })
      const frame = dragging(scene)

      await bench('libavoid, from scratch', () => {
        router.dispose()
        router.route(scene)
      }).run(once)
      await bench('libavoid, one card dragged', () => router.route(frame())).run(once)
      router.dispose()
    })
  }
}
