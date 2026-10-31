import { chordOf, formatChord, type Shortcut } from '../keybindings'

type Props = {
  shortcut: Shortcut
  chord: string
  /** Labels of other shortcuts bound to the same chord. */
  conflicts: string[]
  recording: boolean
  record: () => void
  cancel: () => void
  bind: (chord: string) => void
}

/** One rebindable shortcut. While recording, the next chord pressed becomes its binding. */
export function ShortcutRow({ shortcut, chord, conflicts, recording, record, cancel, bind }: Props) {
  const onKeyDown = (event: React.KeyboardEvent) => {
    if (!recording) return

    event.preventDefault()

    if (event.key === 'Escape' && !event.metaKey && !event.ctrlKey && !event.altKey && !event.shiftKey) {
      // Keeps the dialog open: only this recording ends.
      cancel()

      return
    }

    const pressed = chordOf(event)

    if (pressed) bind(pressed)
  }

  return (
    <tr className={recording ? 'recording' : undefined}>
      <th scope="row">
        <span className="shortcut-label">{shortcut.label}</span>
        <span className="shortcut-detail">{shortcut.detail}</span>
        {conflicts.length > 0 && <span className="shortcut-conflict">Also used by {conflicts.join(', ')}</span>}
      </th>
      <td>
        <button
          type="button"
          className="shortcut-chord"
          aria-label={recording ? `Press a shortcut for ${shortcut.label}` : `Change shortcut for ${shortcut.label}`}
          onClick={record}
          onKeyDown={onKeyDown}
          onBlur={() => recording && cancel()}
        >
          {recording ? (
            'Press keys…'
          ) : chord ? (
            <kbd>{formatChord(chord)}</kbd>
          ) : (
            <span className="shortcut-unbound">None</span>
          )}
        </button>
      </td>
      <td className="shortcut-actions">
        {chord !== shortcut.chord && (
          <button
            type="button"
            className="link"
            title={`Back to ${formatChord(shortcut.chord) || 'none'}`}
            onClick={() => bind(shortcut.chord)}
          >
            Reset
          </button>
        )}
        {chord && (
          <button type="button" className="link shortcut-remove" onClick={() => bind('')}>
            Remove
          </button>
        )}
      </td>
    </tr>
  )
}
