import { HEADER_MAX_LENGTH } from '../geometry'
import { useState } from 'react'

/**
 * Edits a canvas or group header in Markdown. The header saves when the field loses focus, so typing doesn't
 * refit the group or write the workspace on every key. Clearing the field removes the header.
 */
export function HeaderSettings({
  title,
  value,
  change,
}: {
  title: string
  value: string | undefined
  change: (header: string | null) => void
}) {
  const [draft, setDraft] = useState(value ?? '')

  const save = () => {
    const next = draft.trim()

    if (next === (value ?? '').trim()) return

    change(next === '' ? null : next)
  }

  return (
    <section className="header-settings" aria-label={title}>
      <h3>{title}</h3>
      <label htmlFor={`${title}-header`}>Markdown with layout HTML</label>
      <textarea
        id={`${title}-header`}
        rows={5}
        maxLength={HEADER_MAX_LENGTH}
        value={draft}
        placeholder={'# Sprint 14\n<div class="header-row">Ship it</div>'}
        onChange={(event) => setDraft(event.target.value)}
        onBlur={save}
      />
      <p className="header-hint">
        Layout classes: header-row, header-column, header-center, header-end. Scripts and styles are removed.
      </p>
    </section>
  )
}
