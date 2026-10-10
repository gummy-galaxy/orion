import { describe, expect, it } from 'vitest'
import { DEFAULT_KEYBINDINGS, chordOf, conflictsOf, formatChord, matchesChord, normalizeChord } from './keybindings'

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
})
