import type { Area, Camera, Gesture, Rect, SpikeCard, SpikeLink, TaskId } from './types'

/** The trading-card skin's size, so reach and spacing read as they would on a real canvas. */
export const CARD_WIDTH = 198
export const CARD_HEIGHT = 285

const card = (id: string, title: string, area: Area, x: number, y: number): SpikeCard => ({ id, title, area, x, y })

const PILE_X = 1720
const PILE_Y = 40

const PILE_TITLES = ['Rate limits', 'Audit log', 'Dark mode', 'Webhooks', 'Export CSV', 'Search', 'Invite flow', 'Usage page']

/**
 * Three settled clusters, an unlinked note squeezed between two of them, a far-off archive,
 * and a pile of eight new cards dropped on top of each other beside Accounts.
 */
export const CARDS: SpikeCard[] = [
  card('ship', 'Ship 1.0', 'launch', 0, 0),
  card('notes', 'Release notes', 'launch', 260, 0),
  card('site', 'Changelog site', 'launch', 520, 0),
  card('store', 'Store listing', 'launch', 0, 340),
  card('press', 'Press kit', 'launch', 260, 340),

  card('billing', 'Billing notes', 'loose', 560, 360),

  card('signin', 'Sign-in flow', 'accounts', 880, 0),
  card('reset', 'Password reset', 'accounts', 1140, 0),
  card('tokens', 'Session tokens', 'accounts', 1400, 0),
  card('profile', 'Profile page', 'accounts', 880, 340),
  card('sso', 'Legacy SSO', 'accounts', 1140, 340),
  card('twofactor', 'Two-factor', 'accounts', 1400, 340),

  card('guide', 'Guide', 'docs', 1720, 760),
  card('api', 'API reference', 'docs', 1980, 760),
  card('tutorials', 'Tutorials', 'docs', 1720, 1100),
  card('faq', 'FAQ', 'docs', 1980, 1100),

  card('roadmap', 'Old roadmap', 'archive', 4600, 2900),
  card('retro', '2025 retro', 'archive', 4860, 2900),
  card('beta', 'Beta feedback', 'archive', 4600, 3240),
  card('sunset', 'Sunset plan', 'archive', 4860, 3240),

  ...PILE_TITLES.map((title, i) => card(`new${i + 1}`, title, 'new', PILE_X + i * 14, PILE_Y + i * 10)),
]

export const LINKS: SpikeLink[] = [
  { from: 'ship', to: 'notes' },
  { from: 'notes', to: 'site' },
  { from: 'ship', to: 'store' },
  { from: 'store', to: 'press' },
  // The one link between clusters, so following links from Ship 1.0 reaches into Accounts.
  { from: 'ship', to: 'signin' },

  { from: 'signin', to: 'reset' },
  { from: 'signin', to: 'tokens' },
  { from: 'signin', to: 'profile' },
  { from: 'signin', to: 'sso' },
  { from: 'tokens', to: 'twofactor' },

  { from: 'guide', to: 'api' },
  { from: 'guide', to: 'tutorials' },
  { from: 'tutorials', to: 'faq' },

  { from: 'roadmap', to: 'retro' },
  { from: 'roadmap', to: 'beta' },
  { from: 'beta', to: 'sunset' },

  { from: 'new1', to: 'reset' },
  { from: 'new4', to: 'api' },
  { from: 'new4', to: 'new5' },
]

export const AREA_LABELS: Record<Area, string> = {
  launch: 'Launch',
  accounts: 'Accounts',
  docs: 'Docs',
  archive: 'Archive',
  loose: 'Loose note',
  new: 'New',
}

export const AREA_TINTS: Record<Area, string> = {
  launch: 'var(--tint-amber)',
  accounts: 'var(--tint-blue)',
  docs: 'var(--tint-green)',
  archive: 'var(--tint-slate)',
  loose: 'var(--tint-rose)',
  new: 'var(--tint-purple)',
}

/** Where the move task asks Launch to end up: open canvas below it, clear of everything else. */
export const MOVE_ZONE: Rect = { x0: -60, y0: 820, x1: 1100, y1: 1640 }

export const START_CAMERA: Camera = { x: 70, y: 110, zoom: 0.45 }

/** Places the panel's Go to buttons and the minimap jump to. */
export const DESTINATIONS: { label: string; area: Area }[] = [
  { label: 'Launch', area: 'launch' },
  { label: 'Accounts', area: 'accounts' },
  { label: 'Docs', area: 'docs' },
  { label: 'New pile', area: 'new' },
  { label: 'Archive', area: 'archive' },
]

export const TASKS: { id: TaskId; label: string; hint: string }[] = [
  {
    id: 'isolate',
    label: 'Isolate Launch',
    hint: 'Select exactly Launch’s five cards: not Billing notes beside it, and not Sign-in flow, which Ship 1.0 links to.',
  },
  {
    id: 'exclude',
    label: 'Accounts without Legacy SSO',
    hint: 'Select every Accounts card except Legacy SSO, which sits in the middle and is linked to Sign-in flow.',
  },
  { id: 'move', label: 'Move Launch', hint: 'Launch starts selected. Move all five cards into the dashed zone below without nudging anything else.' },
  { id: 'navigate', label: 'Visit the archive', hint: 'Bring all four Archive cards fully on screen. They start far off to the lower right.' },
  {
    id: 'pile',
    label: 'Sort the pile',
    hint: 'Spread the eight new cards so none overlap each other or anything else, without moving a settled card.',
  },
]

export const PRESETS: { id: string; label: string; key: string; gesture: Gesture }[] = [
  { id: 'baseline', label: 'Baseline', key: '1', gesture: { leftDrag: 'box', rightDrag: 'menu', modifiers: 'baseline' } },
  { id: 'sweep', label: 'Sweep', key: '2', gesture: { leftDrag: 'sweep', rightDrag: 'menu', modifiers: 'baseline' } },
  { id: 'magnet', label: 'Magnet', key: '3', gesture: { leftDrag: 'magnet', rightDrag: 'menu', modifiers: 'baseline' } },
  { id: 'gather', label: 'Gather', key: '4', gesture: { leftDrag: 'gather', rightDrag: 'menu', modifiers: 'baseline' } },
  { id: 'right-pan', label: 'Right-drag pan', key: '5', gesture: { leftDrag: 'box', rightDrag: 'pan', modifiers: 'baseline' } },
  { id: 'modifiers', label: 'Modifiers', key: '6', gesture: { leftDrag: 'box', rightDrag: 'menu', modifiers: 'full' } },
]
