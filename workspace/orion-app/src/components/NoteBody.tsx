import { useState, type KeyboardEvent, type MouseEvent } from 'react'
import { Markdown } from './Markdown'

/**
 * A card's note, shown as rendered Markdown. Clicking it swaps in the Markdown source to edit
 * in place, and leaving the source goes back to the rendered view.
 */
export function NoteBody({ id, note, change }: { id: string; note?: string; change: (note: string | undefined) => void }) {
  const [editing, setEditing] = useState(false)

  if (editing)
    return (
      <textarea
        id={id}
        className="note-source"
        aria-label="Note Markdown"
        rows={Math.min(16, Math.max(6, (note ?? '').split('\n').length + 1))}
        value={note ?? ''}
        autoFocus
        placeholder="A plain-language summary. Markdown works: **bold**, lists, `code`, and [links](https://)."
        onBlur={() => setEditing(false)}
        onKeyDown={(event) => event.key === 'Escape' && event.currentTarget.blur()}
        onChange={(event) => change(event.target.value || undefined)}
      />
    )

  // A link inside the rendered note opens on its own, so a click on one must not start editing.
  const startEditing = (event: MouseEvent<HTMLDivElement>) => {
    if ((event.target as HTMLElement).closest('a')) return

    setEditing(true)
  }

  const keyStartsEditing = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.target !== event.currentTarget || (event.key !== 'Enter' && event.key !== ' ')) return

    event.preventDefault()
    setEditing(true)
  }

  return (
    <div className="note-view" role="button" tabIndex={0} title="Click to edit" onClick={startEditing} onKeyDown={keyStartsEditing}>
      {note ? <Markdown source={note} /> : <p className="facts">Add a note</p>}
    </div>
  )
}
