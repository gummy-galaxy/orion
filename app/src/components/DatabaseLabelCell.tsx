import { useState } from 'react'

/**
 * A label the table edits as one change: typing stays local, and the label saves on Enter or when the cell loses focus,
 * so a rename is one undo step and one operation rather than one per keystroke. Escape puts the label back.
 */
export function DatabaseLabelCell({ label, placeholder, save }: { label: string; placeholder: string; save: (label: string) => void }) {
  const [draft, setDraft] = useState<string | null>(null)

  return (
    <td className="db-label">
      <input
        value={draft ?? label}
        aria-label="Label"
        placeholder={placeholder}
        onFocus={() => setDraft(label)}
        onChange={(event) => setDraft(event.target.value)}
        onBlur={() => {
          if (draft !== null && draft !== label) save(draft)

          setDraft(null)
        }}
        onKeyDown={(event) => {
          if (event.key === 'Enter') event.currentTarget.blur()

          if (event.key === 'Escape') {
            setDraft(label)
            requestAnimationFrame(() => (event.target as HTMLInputElement).blur())
          }
        }}
      />
    </td>
  )
}
