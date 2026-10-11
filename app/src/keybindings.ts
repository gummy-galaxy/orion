/**
 * Keyboard shortcuts you can rebind. A chord is written as its modifiers then its key, such as
 * `Mod+Shift+P`, where `Mod` is ⌘ or Ctrl. An empty chord leaves the shortcut unbound.
 */
export type ShortcutId =
  | 'search'
  | 'actions'
  | 'settings'
  | 'undo'
  | 'redo'
  | 'go-back'
  | 'go-forward'
  | 'group'
  | 'ungroup'
  | 'open-group'
  | 'step-back'
  | 'add-note'
  | 'fit'
  | 'less-detail'
  | 'more-detail'
  | 'tool-select'
  | 'tool-hand'
  | 'tool-comment'
  | 'tool-sticker'

export type Shortcut = { id: ShortcutId; label: string; detail: string; category: string; chord: string }

export type Keybindings = Record<ShortcutId, string>

export const SHORTCUTS: readonly Shortcut[] = [
  { id: 'search', label: 'Search canvas', detail: 'Find a group or card', category: 'General', chord: 'Mod+K' },
  { id: 'actions', label: 'Show all actions', detail: 'Open the palette in action mode', category: 'General', chord: 'Mod+Shift+P' },
  { id: 'settings', label: 'Open settings', detail: 'Appearance, scrolling, and keyboard shortcuts', category: 'General', chord: 'Mod+,' },
  { id: 'undo', label: 'Undo', detail: 'Take back the last canvas edit', category: 'Editing', chord: 'Mod+Z' },
  { id: 'redo', label: 'Redo', detail: 'Make the last undone edit again', category: 'Editing', chord: 'Mod+Shift+Z' },
  { id: 'group', label: 'Group selection', detail: 'Put the selected items in a new group', category: 'Editing', chord: 'Mod+G' },
  { id: 'ungroup', label: 'Ungroup', detail: 'Release the selected groups’ contents', category: 'Editing', chord: 'Mod+Shift+G' },
  { id: 'add-note', label: 'Add a note', detail: 'At the middle of the view', category: 'Editing', chord: 'N' },
  { id: 'open-group', label: 'Open group', detail: 'Open the selected group', category: 'Navigation', chord: 'Enter' },
  {
    id: 'step-back',
    label: 'Step back',
    detail: 'Return to Select, leave the open group, or clear the selection',
    category: 'Navigation',
    chord: 'Escape',
  },
  { id: 'go-back', label: 'Go back', detail: 'Return to the previous view', category: 'Navigation', chord: 'Mod+[' },
  { id: 'go-forward', label: 'Go forward', detail: 'Return to the view you went back from', category: 'Navigation', chord: 'Mod+]' },
  { id: 'fit', label: 'Fit to screen', detail: 'Show everything in the open group', category: 'Navigation', chord: 'Shift+1' },
  { id: 'less-detail', label: 'Show less detail', detail: 'Fold one more level of groups', category: 'Navigation', chord: '[' },
  { id: 'more-detail', label: 'Show more detail', detail: 'Open one more level of groups', category: 'Navigation', chord: ']' },
  { id: 'tool-select', label: 'Select tool', detail: 'Drag to select', category: 'Tools', chord: 'V' },
  { id: 'tool-hand', label: 'Pan tool', detail: 'Drag anywhere to pan', category: 'Tools', chord: 'H' },
  { id: 'tool-comment', label: 'Comment tool', detail: 'Click to leave a note', category: 'Tools', chord: 'C' },
  { id: 'tool-sticker', label: 'Sticker tool', detail: 'Hold to pick from the wheel, then click to stamp', category: 'Tools', chord: 'S' },
]

export type Gesture = { label: string; how: string }

/**
 * Gestures that are part of how the canvas works, listed beside the shortcuts but not rebindable.
 * Panning and zooming depend on what scrolling does, so `gesturesOf` adds them.
 */
export const GESTURES: readonly Gesture[] = [
  { label: 'Select', how: 'Drag across empty canvas' },
  { label: 'Add to the selection', how: '⌘ or ⇧ click' },
  { label: 'Actions for an item', how: 'Right-click' },
  { label: 'Open a group', how: 'Double-click it' },
  { label: 'Focus a card', how: 'Double-click it' },
  { label: 'Go up a level', how: 'Double-click empty canvas' },
  { label: 'Hold a card’s trace or edit a note', how: '⇧ double-click' },
  { label: 'Retrace views', how: 'Mouse back and forward buttons' },
  { label: 'Link two items', how: 'Drag from a card’s edge' },
  { label: 'Skip snapping', how: 'Hold Ctrl while dragging' },
  { label: 'See what needs you', how: 'Hold ⌥' },
]

export const DEFAULT_KEYBINDINGS = Object.fromEntries(SHORTCUTS.map((shortcut) => [shortcut.id, shortcut.chord])) as Keybindings

const KEYBINDINGS_KEY = 'orion:keybindings'
const MODIFIERS = ['Mod', 'Alt', 'Shift'] as const
const CODE_KEYS: Record<string, string> = {
  Comma: ',',
  Period: '.',
  Slash: '/',
  Backslash: '\\',
  Semicolon: ';',
  Quote: "'",
  BracketLeft: '[',
  BracketRight: ']',
  Minus: '-',
  Equal: '=',
  Backquote: '`',
  Space: 'Space',
}
const KEY_SYMBOLS: Record<string, string> = {
  Escape: 'Esc',
  Enter: '↵',
  Tab: '⇥',
  Backspace: '⌫',
  Delete: '⌦',
  ArrowUp: '↑',
  ArrowDown: '↓',
  ArrowLeft: '←',
  ArrowRight: '→',
}
// macOS menus list modifiers as ⌥⇧⌘.
const DISPLAY_ORDER = ['Alt', 'Shift', 'Mod'] as const
const MODIFIER_SYMBOLS: Record<(typeof MODIFIERS)[number], string> = { Mod: '⌘', Alt: '⌥', Shift: '⇧' }

type KeyEvent = Pick<KeyboardEvent, 'key' | 'code' | 'metaKey' | 'ctrlKey' | 'altKey' | 'shiftKey'>

/**
 * The key a press names, layout first: a letter or digit comes from the character typed, and
 * falls back to its position when a modifier changes it, as ⇧1 types `!` and ⌥N types `˜`.
 */
function keyOf(event: KeyEvent): string | null {
  if (['Meta', 'Control', 'Alt', 'Shift', 'CapsLock', 'Fn'].includes(event.key)) return null

  if (/^[a-z0-9]$/i.test(event.key)) return event.key.toUpperCase()

  const letterOrDigit = /^(?:Key([A-Z])|Digit([0-9]))$/.exec(event.code)

  if (letterOrDigit) return letterOrDigit[1] ?? letterOrDigit[2]

  return CODE_KEYS[event.code] ?? (event.key || null)
}

/** The chord a key press makes, or null while only modifiers are down. */
export function chordOf(event: KeyEvent): string | null {
  const key = keyOf(event)

  if (!key) return null

  const held = { Mod: event.metaKey || event.ctrlKey, Alt: event.altKey, Shift: event.shiftKey }

  return [...MODIFIERS.filter((modifier) => held[modifier]), key].join('+')
}

/** Writes a chord in one canonical order, so `Shift+Mod+p` and `Mod+Shift+P` compare equal. */
export function normalizeChord(chord: string): string {
  if (!chord) return ''

  const parts = chord.split('+')
  const key = parts.pop() ?? ''
  const held = new Set(parts.map((part) => part.toLowerCase()))
  const modifiers = MODIFIERS.filter((modifier) => held.has(modifier.toLowerCase()) || (modifier === 'Mod' && (held.has('cmd') || held.has('ctrl'))))

  return [...modifiers, key.length === 1 ? key.toUpperCase() : key].join('+')
}

export function matchesChord(event: KeyEvent, chord: string): boolean {
  return chord !== '' && chordOf(event) === chord
}

/** Whether a press or release is on a chord's key, whatever modifiers are down, for a key that's held. */
export function isChordKey(event: KeyEvent, chord: string): boolean {
  return chord !== '' && keyOf(event) === chord.split('+').pop()
}

/** A chord as the app shows it, such as ⇧⌘P. */
export function formatChord(chord: string): string {
  if (!chord) return ''

  const parts = chord.split('+')
  const key = parts.pop() ?? ''
  const modifiers = DISPLAY_ORDER.filter((modifier) => parts.includes(modifier)).map((modifier) => MODIFIER_SYMBOLS[modifier])

  return modifiers.join('') + (KEY_SYMBOLS[key] ?? key)
}

/** A label with its shortcut after it, for a tooltip, such as Search (⌘K). */
export function withChord(label: string, chord: string): string {
  return chord ? `${label} (${formatChord(chord)})` : label
}

/** The other shortcuts already bound to a chord. */
export function conflictsOf(bindings: Keybindings, id: ShortcutId): ShortcutId[] {
  const chord = bindings[id]

  if (!chord) return []

  return SHORTCUTS.filter((shortcut) => shortcut.id !== id && bindings[shortcut.id] === chord).map((shortcut) => shortcut.id)
}

/** Only changed bindings are saved, so a later default change reaches anyone who kept the old one. */
export function readKeybindings(): Keybindings {
  try {
    const saved: unknown = JSON.parse(localStorage.getItem(KEYBINDINGS_KEY) ?? '{}')
    const bindings = { ...DEFAULT_KEYBINDINGS }

    if (saved && typeof saved === 'object') {
      for (const [id, chord] of Object.entries(saved)) {
        if (id in bindings && typeof chord === 'string') bindings[id as ShortcutId] = normalizeChord(chord)
      }
    }

    return bindings
  } catch {
    return { ...DEFAULT_KEYBINDINGS }
  }
}

export function writeKeybindings(bindings: Keybindings) {
  const changed = Object.fromEntries(
    SHORTCUTS.filter((shortcut) => bindings[shortcut.id] !== shortcut.chord).map((shortcut) => [shortcut.id, bindings[shortcut.id]]),
  )

  try {
    if (Object.keys(changed).length) localStorage.setItem(KEYBINDINGS_KEY, JSON.stringify(changed))
    else localStorage.removeItem(KEYBINDINGS_KEY)
  } catch {
    // Only a remembered preference.
  }
}
