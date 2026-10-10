import { useState } from 'react'
import { DEFAULT_KEYBINDINGS, GESTURES, SHORTCUTS, conflictsOf, formatChord, type Keybindings, type ShortcutId } from '../keybindings'
import { ShortcutRow } from './ShortcutRow'

type Props = { keybindings: Keybindings; chooseKeybindings: (keybindings: Keybindings) => void }

/** Every rebindable shortcut by category, then the gestures that can't change. */
export function ShortcutSettings({ keybindings, chooseKeybindings }: Props) {
  const [query, setQuery] = useState('')
  const [recording, setRecording] = useState<ShortcutId | null>(null)
  const term = query.trim().toLowerCase()
  const found = (...values: string[]) => !term || values.some((value) => value.toLowerCase().includes(term))
  const shortcuts = SHORTCUTS.filter((shortcut) =>
    found(shortcut.label, shortcut.detail, shortcut.category, keybindings[shortcut.id], formatChord(keybindings[shortcut.id])),
  )
  const categories = [...new Set(shortcuts.map((shortcut) => shortcut.category))]
  const gestures = GESTURES.filter((gesture) => found(gesture.label, gesture.how))
  const changed = SHORTCUTS.some((shortcut) => keybindings[shortcut.id] !== shortcut.chord)
  const labelOf = (id: ShortcutId) => SHORTCUTS.find((shortcut) => shortcut.id === id)?.label ?? id

  const bind = (id: ShortcutId, chord: string) => {
    setRecording(null)
    chooseKeybindings({ ...keybindings, [id]: chord })
  }

  return (
    <section className="settings-section">
      <h3>Keyboard Shortcuts</h3>
      <div className="shortcut-tools">
        <input
          type="search"
          className="settings-search"
          aria-label="Search shortcuts"
          placeholder="Search by action or key"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
        {changed && (
          <button type="button" className="link" onClick={() => chooseKeybindings({ ...DEFAULT_KEYBINDINGS })}>
            Reset all
          </button>
        )}
      </div>
      <p className="settings-field-detail">Click a shortcut, then press the keys you want. Esc cancels.</p>
      {categories.map((category) => (
        <table key={category} className="shortcut-table">
          <caption>{category}</caption>
          <tbody>
            {shortcuts
              .filter((shortcut) => shortcut.category === category)
              .map((shortcut) => (
                <ShortcutRow
                  key={shortcut.id}
                  shortcut={shortcut}
                  chord={keybindings[shortcut.id]}
                  conflicts={conflictsOf(keybindings, shortcut.id).map(labelOf)}
                  recording={recording === shortcut.id}
                  record={() => setRecording(shortcut.id)}
                  cancel={() => setRecording(null)}
                  bind={(chord) => bind(shortcut.id, chord)}
                />
              ))}
          </tbody>
        </table>
      ))}
      {gestures.length > 0 && (
        <table className="shortcut-table">
          <caption>Mouse and held keys</caption>
          <tbody>
            {gestures.map((gesture) => (
              <tr key={gesture.label}>
                <th scope="row">{gesture.label}</th>
                <td className="shortcut-fixed">{gesture.how}</td>
                <td />
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {!categories.length && !gestures.length && <p className="settings-empty">No shortcuts match “{query.trim()}”.</p>}
    </section>
  )
}
