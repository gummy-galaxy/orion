import { describe, expect, it } from 'vitest'
import { DEFAULT_KEYBINDINGS, SHORTCUTS, chordOf, conflictsOf, formatChord, matchesChord, normalizeChord } from './keybindings'
import { largeChordOf } from './nudge'

const press = (key: string, code: string, held: { meta?: boolean; ctrl?: boolean; alt?: boolean; shift?: boolean } = {}) => ({
  key,
  code,
  metaKey: held.meta ?? false,
  ctrlKey: held.ctrl ?? false,
  altKey: held.alt ?? false,
  shiftKey: held.shift ?? false,
})

describe('keybindings', () => {
  it('reads a chord from a key press', () => {
    expect(chordOf(press('p', 'KeyP', { meta: true, shift: true }))).toBe('Mod+Shift+P')
    expect(chordOf(press('k', 'KeyK', { ctrl: true }))).toBe('Mod+K')
    expect(chordOf(press('Escape', 'Escape'))).toBe('Escape')
    expect(chordOf(press(',', 'Comma', { meta: true }))).toBe('Mod+,')
  })

  it('waits for a key while only modifiers are down', () => {
    expect(chordOf(press('Shift', 'ShiftLeft', { shift: true }))).toBeNull()
    expect(chordOf(press('Meta', 'MetaLeft', { meta: true }))).toBeNull()
  })

  it('names the key by position when a modifier changes the character', () => {
    expect(chordOf(press('!', 'Digit1', { shift: true }))).toBe('Shift+1')
    expect(chordOf(press('˜', 'KeyN', { alt: true }))).toBe('Alt+N')
  })

  it('follows the keyboard layout for plain letters', () => {
    // Dvorak's K sits where QWERTY has V.
    expect(chordOf(press('k', 'KeyV'))).toBe('K')
  })

  it('matches only the exact modifiers', () => {
    expect(matchesChord(press('n', 'KeyN'), 'N')).toBe(true)
    expect(matchesChord(press('n', 'KeyN', { meta: true }), 'N')).toBe(false)
    expect(matchesChord(press('n', 'KeyN'), '')).toBe(false)
  })

  it('normalizes chords written in any order or case', () => {
    expect(normalizeChord('shift+cmd+p')).toBe('Mod+Shift+P')
    expect(normalizeChord('Ctrl+Alt+Escape')).toBe('Mod+Alt+Escape')
    expect(normalizeChord('')).toBe('')
  })

  it('formats chords the way macOS menus do', () => {
    expect(formatChord('Mod+Shift+P')).toBe('⇧⌘P')
    expect(formatChord('Mod+Alt+Shift+K')).toBe('⌥⇧⌘K')
    expect(formatChord('Escape')).toBe('Esc')
    expect(formatChord('Shift+1')).toBe('⇧1')
  })

  it('finds other shortcuts on the same chord', () => {
    expect(conflictsOf(DEFAULT_KEYBINDINGS, 'undo')).toEqual([])
    expect(conflictsOf({ ...DEFAULT_KEYBINDINGS, 'add-note': 'V' }, 'add-note')).toEqual(['tool-select'])
    expect(conflictsOf({ ...DEFAULT_KEYBINDINGS, 'add-note': '' }, 'add-note')).toEqual([])
  })

  it('gives every default shortcut its own chord', () => {
    const chords = Object.values(DEFAULT_KEYBINDINGS)

    expect(new Set(chords).size).toBe(chords.length)
  })

  it('binds the familiar shortcuts to the actions they name', () => {
    expect(DEFAULT_KEYBINDINGS.rename).toBe('F2')
    expect(DEFAULT_KEYBINDINGS['fit-selection']).toBe('Shift+2')
    expect(DEFAULT_KEYBINDINGS['bring-forward']).toBe('Mod+Alt+]')
    expect(DEFAULT_KEYBINDINGS['send-backward']).toBe('Mod+Alt+[')
    expect(DEFAULT_KEYBINDINGS['nudge-left']).toBe('ArrowLeft')
    expect(DEFAULT_KEYBINDINGS['select-all']).toBe('Mod+A')
    expect(DEFAULT_KEYBINDINGS['zoom-actual']).toBe('Shift+0')
  })

  it('keeps bring forward and send backward apart from back and forward navigation', () => {
    expect(DEFAULT_KEYBINDINGS['go-forward']).toBe('Mod+]')
    expect(DEFAULT_KEYBINDINGS['go-back']).toBe('Mod+[')
    expect(matchesChord(press(']', 'BracketRight', { meta: true, alt: true }), DEFAULT_KEYBINDINGS['bring-forward'])).toBe(true)
    expect(matchesChord(press(']', 'BracketRight', { meta: true }), DEFAULT_KEYBINDINGS['bring-forward'])).toBe(false)
    expect(matchesChord(press('[', 'BracketLeft', { meta: true, alt: true }), DEFAULT_KEYBINDINGS['send-backward'])).toBe(true)
  })

  it('reads the new chords from key presses', () => {
    expect(chordOf(press('F2', 'F2'))).toBe('F2')
    expect(chordOf(press('@', 'Digit2', { shift: true }))).toBe('Shift+2')
    expect(chordOf(press(')', 'Digit0', { shift: true }))).toBe('Shift+0')
    expect(chordOf(press('a', 'KeyA', { meta: true }))).toBe('Mod+A')
    expect(chordOf(press('ArrowLeft', 'ArrowLeft', { shift: true }))).toBe('Shift+ArrowLeft')
  })

  it('formats the new chords the way macOS menus do', () => {
    expect(formatChord(DEFAULT_KEYBINDINGS['bring-forward'])).toBe('⌥⌘]')
    expect(formatChord(DEFAULT_KEYBINDINGS['send-backward'])).toBe('⌥⌘[')
    expect(formatChord('F2')).toBe('F2')
    expect(formatChord(DEFAULT_KEYBINDINGS['nudge-up'])).toBe('↑')
    expect(formatChord(largeChordOf(DEFAULT_KEYBINDINGS['nudge-up']))).toBe('⇧↑')
  })

  it('lists each new action once in the Editing or Navigation category', () => {
    const ids = [
      'copy',
      'cut',
      'paste',
      'duplicate',
      'select-all',
      'rename',
      'bring-forward',
      'send-backward',
      'nudge-up',
      'nudge-down',
      'nudge-left',
      'nudge-right',
      'fit-selection',
      'zoom-actual',
    ]

    for (const id of ids) {
      expect(SHORTCUTS.filter((shortcut) => shortcut.id === id)).toHaveLength(1)
    }

    expect(SHORTCUTS.find((shortcut) => shortcut.id === 'fit-selection')?.category).toBe('Navigation')
  })

  it('makes the large nudge by adding ⇧ to the arrow chord', () => {
    expect(largeChordOf('ArrowLeft')).toBe('Shift+ArrowLeft')
    expect(largeChordOf('Mod+ArrowLeft')).toBe('Mod+Shift+ArrowLeft')
    expect(largeChordOf('')).toBe('')
  })
})
