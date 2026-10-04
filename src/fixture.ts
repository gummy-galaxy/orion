import type { AppNode, Link, Status, Who } from './model'

// Sample data until real sources are connected. Positions are computed by the first layout.
const groups: [id: string, label: string, parent?: string][] = [
  ['rel', 'Release pipeline'],
  ['sign', 'Code signing', 'rel'],
  ['search', 'Search'],
  ['docs', 'Docs refresh'],
  ['obs', 'Observability'],
]

const tasks: [id: string, label: string, tag: string, status: Status, parent?: string, who?: Who][] = [
  ['r1', 'Pin toolchain versions', 'hop#41', 'done', 'rel'],
  ['r2', 'Build matrix in CI', 'hop#44', 'review', 'rel', 'review'],
  ['r3', 'Cache tool installs', 'hop#45', 'done', 'rel'],
  ['r4', 'Release workflow', 'hop#47', 'active', 'rel', 'you'],
  ['r5', 'Publish binaries', 'hop#48', 'todo', 'rel'],
  ['r6', 'Install script', 'hop#49', 'todo', 'rel'],
  ['r7', 'Announce v0.2', 'step', 'todo', 'rel'],
  ['s1', 'Apple developer certificate', 'step', 'done', 'sign'],
  ['s2', 'Notarize macOS builds', 'hop#50', 'active', 'sign', 'you'],
  ['s3', 'Sign Windows builds', 'hop#51', 'todo', 'sign'],
  ['q1', 'Index schema', 'api#60', 'done', 'search'],
  ['q2', 'Tokenizer', 'api#61', 'done', 'search'],
  ['q3', 'Backfill job', 'api#62', 'review', 'search', 'ci'],
  ['q4', 'Ranking tweaks', 'api#64', 'active', 'search', 'you'],
  ['q5', 'Search box', 'web#130', 'todo', 'search'],
  ['q6', 'Result highlighting', 'web#131', 'todo', 'search'],
  ['q7', 'Keyboard navigation', 'web#133', 'todo', 'search'],
  ['q8', 'Search analytics', 'api#66', 'todo', 'search'],
  ['q9', 'Typo tolerance', 'api#65', 'todo', 'search'],
  ['d1', 'Audit stale pages', 'docs#11', 'done', 'docs'],
  ['d2', 'Rewrite quickstart', 'docs#12', 'done', 'docs'],
  ['d3', 'Redirect old URLs', 'docs#13', 'review', 'docs', 'review'],
  ['d4', 'Install guide', 'docs#15', 'todo', 'docs'],
  ['d5', 'Search docs', 'docs#16', 'todo', 'docs'],
  ['d6', 'Announce new docs', 'step', 'todo', 'docs'],
  ['o1', 'Structured logging', 'api#70', 'done', 'obs'],
  ['o2', 'Trace IDs in requests', 'api#71', 'active', 'obs', 'you'],
  ['o3', 'Error dashboard', 'ops#8', 'todo', 'obs'],
  ['o4', 'Alert routing', 'ops#9', 'todo', 'obs'],
  ['o5', 'Client error capture', 'web#140', 'review', 'obs', 'review'],
  ['o6', 'Release health check', 'hop#53', 'todo', 'obs'],
  ['o7', 'On-call runbook', 'docs#18', 'todo', 'obs'],
  ['o8', 'Sampling config', 'api#72', 'todo', 'obs'],
  ['l1', 'Answer API question', 'step', 'todo', undefined, 'you'],
  ['l2', 'Rotate CI token', 'step', 'todo'],
  ['l3', 'Bump lint config', 'web#150', 'review', undefined, 'ci'],
  ['l4', 'Fix flaky upload test', 'cli#52', 'todo'],
  ['l5', 'Update README badge', 'hop#55', 'done'],
]

const blocks: [from: string, to: string][] = [
  ['r1', 'r2'],
  ['r3', 'r2'],
  ['r2', 'r4'],
  ['r4', 'r5'],
  ['r4', 'r6'],
  ['s1', 's2'],
  ['s1', 's3'],
  ['s2', 'r5'],
  ['s3', 'r5'],
  ['r5', 'r7'],
  ['r6', 'r7'],
  ['q1', 'q2'],
  ['q1', 'q3'],
  ['q2', 'q4'],
  ['q3', 'q4'],
  ['q4', 'q5'],
  ['q5', 'q6'],
  ['q5', 'q7'],
  ['q3', 'q8'],
  ['q2', 'q9'],
  ['q9', 'q6'],
  ['d1', 'd2'],
  ['d2', 'd3'],
  ['d4', 'd6'],
  ['d5', 'd6'],
  ['d3', 'd6'],
  ['r6', 'd4'],
  ['q5', 'd5'],
  ['o1', 'o2'],
  ['o2', 'o3'],
  ['o5', 'o3'],
  ['o3', 'o4'],
  ['o3', 'o6'],
  ['o4', 'o7'],
  ['o1', 'o8'],
  ['r4', 'o6'],
  ['l4', 'r2'],
]

const related: [from: string, to: string][] = [
  ['q8', 'o3'],
  ['d5', 'q6'],
]

export function sampleNodes(): AppNode[] {
  return [
    ...groups.map(([id, label, parent]): AppNode => ({
      id,
      type: 'cluster',
      position: { x: 0, y: 0 },
      parentId: parent,
      data: { kind: 'cluster', label },
    })),
    ...tasks.map(([id, label, tag, status, parent, who]): AppNode => ({
      id,
      type: 'task',
      position: { x: 0, y: 0 },
      parentId: parent,
      data: { kind: 'task', label, tag, status, who },
    })),
  ]
}

export function sampleLinks(): Link[] {
  return [
    ...blocks.map(([from, to]): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })),
    ...related.map(([from, to]): Link => ({ id: `${from}~${to}`, from, to, kind: 'related' })),
  ]
}
