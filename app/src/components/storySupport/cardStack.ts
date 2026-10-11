import {
  GROUP_HEADER_HEIGHT,
  GROUP_PADDING,
  normalize,
  type AppNode,
  type ClusterNode,
  type Link,
  type PullDetails,
  type TaskData,
  type TaskNode,
} from '../../model'

/** Two groups from Orion's own canvas: the card skin pull request stack, and the navigation work. */

const CARD = { width: 264, height: 380 }
const GAP = { x: 56, y: 40 }

// Relative to now, so sample pull requests don't turn stale as the snapshot ages.
const hoursAgo = (hours: number) => new Date(Date.now() - hours * 60 * 60 * 1000).toISOString()

function pull(number: number, details: Partial<PullDetails>): TaskData['refs'] {
  const full: PullDetails = {
    state: 'OPEN',
    draft: false,
    title: '',
    author: 'vocksel',
    mine: true,
    requestedFromYou: false,
    updatedAt: hoursAgo(2),
    additions: 0,
    deletions: 0,
    checkedAt: hoursAgo(0),
    ...details,
  }

  return [
    {
      source: 'github',
      kind: 'pull',
      key: `vocksel/orion#${number}`,
      url: `https://github.com/vocksel/orion/pull/${number}`,
      details: full,
    },
  ]
}

function at(column: number, row: number) {
  return { x: GROUP_PADDING + column * (CARD.width + GAP.x), y: GROUP_HEADER_HEIGHT + row * (CARD.height + GAP.y) }
}

function card(id: string, parentId: string, column: number, row: number, data: Omit<TaskData, 'kind'>): TaskNode {
  return { id, type: 'task', parentId, position: at(column, row), data: { kind: 'task', ...data } }
}

function group(id: string, label: string, y: number, columns: number, rows: number): ClusterNode {
  return {
    id,
    type: 'cluster',
    position: { x: 0, y },
    width: GROUP_PADDING * 2 + columns * CARD.width + (columns - 1) * GAP.x,
    height: GROUP_HEADER_HEIGHT + GROUP_PADDING + rows * CARD.height + (rows - 1) * GAP.y,
    data: { kind: 'cluster', label },
  }
}

const prQueue = group('pr-queue', 'PR queue', 0, 6, 2)
const navigation = group('navigation', 'Navigation', prQueue.height! + 120, 4, 2)

// Normalizing sizes every card for the slot skin and fits each group around its cards, as the canvas does.
export const stackNodes: AppNode[] = normalize(
  [
    prQueue,
    card('registry', prQueue.id, 0, 0, {
      itemKind: 'pr',
      label: 'Add a card skin registry with Classic and Plain skins',
      status: 'done',
      repo: 'vocksel/orion',
      refs: pull(157, { state: 'MERGED', checks: 'SUCCESS' }),
    }),
    card('skin-card-size', prQueue.id, 1, 0, {
      itemKind: 'pr',
      label: "Lay out cards at the active skin's size",
      status: 'review',
      who: 'you',
      repo: 'vocksel/orion',
      refs: pull(158, { checks: 'SUCCESS', mergeable: 'MERGEABLE', mergeState: 'CLEAN' }),
    }),
    card('trading-card-skin', prQueue.id, 2, 0, {
      itemKind: 'pr',
      label: 'Add a trading card skin',
      status: 'review',
      who: 'you',
      repo: 'vocksel/orion',
      refs: pull(159, { checks: 'PENDING', checkProgress: 'waiting', mergeable: 'MERGEABLE', mergeState: 'UNSTABLE' }),
    }),
    card('card-rarity', prQueue.id, 3, 0, {
      itemKind: 'pr',
      label: 'Give cards a rarity from the work that feeds into them',
      status: 'review',
      who: 'you',
      repo: 'vocksel/orion',
      refs: pull(161, { checks: 'FAILURE', mergeable: 'MERGEABLE', mergeState: 'UNSTABLE' }),
    }),
    card('card-kind-identity', prQueue.id, 4, 0, {
      itemKind: 'pr',
      label: 'Give each card kind its own silhouette, symbol, and tint',
      status: 'review',
      who: 'you',
      repo: 'vocksel/orion',
      refs: pull(162, { checks: 'PENDING', checkProgress: 'running', mergeable: 'MERGEABLE', mergeState: 'UNSTABLE' }),
    }),
    card('card-poster-art', prQueue.id, 5, 0, {
      itemKind: 'pr',
      label: 'Draw trading card art as geometric posters built from each card',
      status: 'review',
      who: 'you',
      repo: 'vocksel/orion',
      refs: pull(164, { checks: 'FAILURE', mergeable: 'MERGEABLE', mergeState: 'UNSTABLE' }),
    }),
    card('snap-nearby', prQueue.id, 2, 1, {
      itemKind: 'pr',
      label: 'Snap only to nearby nodes',
      status: 'review',
      who: 'review',
      repo: 'vocksel/orion',
      refs: pull(243, { checks: 'SUCCESS', reviewDecision: 'CHANGES_REQUESTED', mergeable: 'MERGEABLE', mergeState: 'BLOCKED' }),
    }),
    card('select-stickers', prQueue.id, 3, 1, {
      itemKind: 'pr',
      label: 'Select stickers like cards',
      status: 'review',
      who: 'you',
      repo: 'vocksel/orion',
      refs: pull(250, { draft: true, checks: 'SUCCESS', mergeable: 'CONFLICTING', mergeState: 'DIRTY' }),
    }),
    card('stack-release', prQueue.id, 4, 1, { itemKind: 'gate', label: 'Card skins ship', status: 'todo' }),
    card('stack-note', prQueue.id, 5, 1, {
      itemKind: 'note',
      label: 'Merge the stack bottom up so each child picks up its parent before review.',
      status: 'todo',
    }),
    navigation,
    card('palette-command-mode', navigation.id, 0, 0, {
      itemKind: 'step',
      label: 'List commands after `>` in the command palette',
      status: 'todo',
      refs: [{ source: 'github', kind: 'issue', key: 'vocksel/orion#68', url: 'https://github.com/vocksel/orion/issues/68' }],
    }),
    card('palette-recents', navigation.id, 1, 0, {
      itemKind: 'step',
      label: 'Remember recently used commands in the command palette',
      status: 'todo',
      refs: [{ source: 'github', kind: 'issue', key: 'vocksel/orion#58', url: 'https://github.com/vocksel/orion/issues/58' }],
    }),
    card('always-pan', navigation.id, 2, 0, {
      itemKind: 'pr',
      label: 'Always pan on scroll and drop the Scroll to setting',
      status: 'review',
      who: 'you',
      repo: 'vocksel/orion',
      refs: pull(268, { checks: 'FAILURE', mergeable: 'MERGEABLE', mergeState: 'UNSTABLE' }),
    }),
    card('far-tag-hover', navigation.id, 3, 0, {
      itemKind: 'pr',
      label: "Show a card's far-zoom tag only while hovered or selected",
      status: 'review',
      who: 'you',
      repo: 'vocksel/orion',
      refs: pull(272, { checks: 'PENDING', checkProgress: 'running', mergeable: 'MERGEABLE', mergeState: 'UNSTABLE' }),
    }),
    card('pan-through-links', navigation.id, 0, 1, {
      itemKind: 'pr',
      label: 'Pan through links and move groups by their header in Pan',
      status: 'review',
      who: 'you',
      repo: 'vocksel/orion',
      refs: pull(271, { checks: 'PENDING', checkProgress: 'waiting', mergeable: 'MERGEABLE', mergeState: 'UNSTABLE' }),
    }),
    card('pan-touchpad', navigation.id, 1, 1, {
      itemKind: 'pr',
      label: 'Pan with touchpad and hide shortcuts by default',
      status: 'deferred',
      repo: 'vocksel/orion',
      refs: pull(48, { checks: 'SUCCESS', mergeable: 'MERGEABLE', mergeState: 'CLEAN', updatedAt: hoursAgo(24 * 40) }),
    }),
    card('scroll-zooms-setting', navigation.id, 2, 1, {
      itemKind: 'placeholder',
      label: 'Let the scroll setting follow the trackpad',
      status: 'todo',
      repo: 'vocksel/orion',
    }),
    card('canvas-search', navigation.id, 3, 1, {
      itemKind: 'pr',
      label: 'Search the canvas with Cmd+K and list actions',
      status: 'done',
      repo: 'vocksel/orion',
      refs: pull(191, { state: 'MERGED', checks: 'SUCCESS' }),
    }),
  ],
  CARD,
)

const blocks = (from: string, to: string): Link => ({ id: `${from}-${to}`, from, to, kind: 'blocks' })

export const stackLinks: Link[] = [
  blocks('registry', 'skin-card-size'),
  blocks('skin-card-size', 'trading-card-skin'),
  blocks('trading-card-skin', 'card-rarity'),
  blocks('card-rarity', 'card-kind-identity'),
  blocks('card-kind-identity', 'card-poster-art'),
  blocks('skin-card-size', 'snap-nearby'),
  blocks('card-poster-art', 'stack-release'),
  blocks('snap-nearby', 'stack-release'),
  blocks('palette-command-mode', 'palette-recents'),
  blocks('always-pan', 'scroll-zooms-setting'),
]
