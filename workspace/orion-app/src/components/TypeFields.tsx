import type { KeyboardEvent } from 'react'
import { CORE_FIELDS } from '../cardTypes/coreFields'
import { findCardType } from '../cardTypes/findCardType'
import { getFieldValues } from '../cardTypes/getFieldValues'
import { getItemTypes } from '../cardTypes/getItemTypes'
import type { FieldValue } from '../cardTypes/types'
import type { CardFields } from '../fields/types'
import type { TaskData } from '../model'

const blurOnEnter = (event: KeyboardEvent<HTMLInputElement>) => {
  if (event.key === 'Enter') event.currentTarget.blur()
}

/** One declared field's input, which saves its text when it changes, or on leaving a text box. */
function FieldInput({ id, entry, save }: { id: string; entry: FieldValue; save: (text: string) => void }) {
  const { field, value } = entry
  const text = value === undefined ? '' : String(value)
  // Remounting on a new value shows what the server saved, including a rejected edit put back.
  const key = `${field.name}:${text}`

  if (field.kind === 'boolean') {
    return (
      <input
        id={id}
        key={key}
        type="checkbox"
        defaultChecked={value === true}
        onChange={(event) => save(String(event.target.checked))}
      />
    )
  }

  if (field.kind === 'choice') {
    return (
      <select id={id} key={key} defaultValue={text} onChange={(event) => save(event.target.value)}>
        <option value="">None</option>
        {field.choices?.map((choice) => (
          <option key={choice.value} value={choice.value}>
            {choice.label}
          </option>
        ))}
      </select>
    )
  }

  if (field.kind === 'markdown') {
    return (
      <textarea
        id={id}
        key={key}
        defaultValue={text}
        rows={3}
        onBlur={(event) => event.target.value !== text && save(event.target.value)}
      />
    )
  }

  return (
    <input
      id={id}
      key={key}
      type={field.kind === 'date' ? 'date' : field.kind === 'url' ? 'url' : 'text'}
      inputMode={field.kind === 'number' ? 'decimal' : undefined}
      defaultValue={text}
      onBlur={(event) => event.target.value !== text && save(event.target.value)}
      onKeyDown={blurOnEnter}
    />
  )
}

/**
 * The card's types and the fields they declare beyond the inspector's own, drawn from the declarations, so a type a
 * source adds is editable with no app change. Nothing shows for a card whose types declare no such fields.
 */
export function TypeFields({ data, save }: { data: TaskData; save: (fields: CardFields) => void }) {
  const entries = getFieldValues(data).filter((entry) => !CORE_FIELDS.has(entry.field.name))

  if (entries.length === 0) return null

  const labels = getItemTypes(data).types.map((name) => findCardType(name)?.label ?? name)

  return (
    <div className="type-fields">
      <p className="facts">{labels.join(' · ')}</p>
      {entries.map((entry) => {
        const id = `t-field-${entry.field.name}`

        return (
          <div key={entry.field.name} className="type-field">
            <label htmlFor={id}>{entry.field.label}</label>
            <FieldInput id={id} entry={entry} save={(text) => save({ values: { [entry.field.name]: text } })} />
          </div>
        )
      })}
    </div>
  )
}
