import { test } from 'vitest'
import { deriveWork, needsAttention, traceFrom } from '../derive'
import { reflow } from '../layout'
import { mergeDocs } from '../merge'
import { isTask, normalize, type AppNode } from '../model'
import { fingerprint, type Saved } from '../persist'
import { snapDrag } from '../snap'
import { generateCanvas } from './fixture'

const SIZES = [1000, 5000]
const RUN = { time: 400, iterations: 12, warmupTime: 100 }

/** The same canvas with every `step`th card changed, as another writer would leave it. */
function edit(saved: Saved, step: number, change: (node: AppNode) => AppNode): Saved {
  return { ...saved, nodes: saved.nodes.map((node, index) => (isTask(node) && index % step === 0 ? change(node) : node)) }
}

for (const cards of SIZES) {
  const saved = generateCanvas({ cards })
  const { nodes, links } = saved
  const work = deriveWork(nodes, links)
  const taskIds = nodes.filter(isTask).map((node) => node.id)
  const middle = taskIds[Math.floor(taskIds.length / 2)]
  const dragged = taskIds.slice(0, 1)
  const local = edit(saved, 7, (node) => ({ ...node, position: { x: node.position.x + 12, y: node.position.y } }))
  const remote = edit(saved, 11, (node) => (isTask(node) ? { ...node, data: { ...node.data, status: 'done' } } : node))

  test(`${cards} cards`, async ({ bench }) => {
    await bench('deriveWork', () => deriveWork(nodes, links)).run(RUN)
    await bench('traceFrom', () => traceFrom(middle, work.preds, work.succs, taskIds)).run(RUN)
    await bench('needsAttention', () => needsAttention(nodes, work.status)).run(RUN)
    await bench('normalize', () => normalize(nodes)).run(RUN)
    await bench('fingerprint', () => fingerprint(saved)).run(RUN)
    await bench('mergeDocs', () => mergeDocs(saved, local, remote)).run(RUN)
    await bench('snapDrag', () => snapDrag(nodes, dragged, 8)).run(RUN)
    await bench('reflow group', () => reflow(nodes, links, 'group-0')).run(RUN)
    await bench('reflow top level', () => reflow(nodes, links, undefined)).run(RUN)
  })
}
