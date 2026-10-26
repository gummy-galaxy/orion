import type { Field, FieldValue } from './types'

/** A field's value as a card shows it: a choice by its label, a link by its host, and a date in the reader's words. */
export function formatFieldValue(field: Field, value: FieldValue['value']): string | undefined {
  if (value === undefined || value === '') return undefined

  if (field.kind === 'boolean') return value ? 'Yes' : 'No'

  if (field.kind === 'choice') return field.choices?.find((choice) => choice.value === value)?.label ?? String(value)

  if (field.kind === 'url') {
    try {
      return new URL(String(value)).hostname
    } catch {
      return String(value)
    }
  }

  if (field.kind === 'date') {
    const date = new Date(`${String(value)}T00:00:00`)

    return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  }

  return String(value)
}
