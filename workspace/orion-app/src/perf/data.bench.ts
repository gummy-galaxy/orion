import { test } from 'vitest'
import { buildWork, deriveSources, toServerFacts, traceFrom } from '../derive'
import { reflow } from '../layout'
import { isTask, normalize } from '../model'
import { fingerprint } from '../persist'
import { snapDrag } from '../snap'
import { generateCanvas } from './fixture'

const SIZES = [1000, 5000, 10000]
const RUN = { time: 400, iterations: 12, warmupTime: 100 }

for (const cards of SIZES) {
  const saved = generateCanvas({ cards })
  const { nodes, links } = saved
  const work = buildWork(toServerFacts(null), nodes, links)
  const taskIds = nodes.filter(isTask).map((node) => node.id)
  const middle = taskIds[Math.floor(taskIds.length / 2)]
  const dragged = taskIds.slice(0, 1)

  test(`${cards} cards`, async ({ bench }) => {
    await bench('buildWork', () => buildWork(toServerFacts(null), nodes, links)).run(RUN)
    await bench('deriveSources', () => deriveSources(nodes)).run(RUN)
    await bench('traceFrom', () => traceFrom(middle, work.preds, work.succs, taskIds)).run(RUN)
    await bench('normalize', () => normalize(nodes)).run(RUN)
    await bench('fingerprint', () => fingerprint(saved)).run(RUN)
    await bench('snapDrag', () => snapDrag(nodes, dragged, 8, 160)).run(RUN)
    await bench('reflow group', () => reflow(nodes, links, 'group-0')).run(RUN)
    await bench('reflow top level', () => reflow(nodes, links, undefined)).run(RUN)
  })
}
