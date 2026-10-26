import type { TaskData } from '../model'
import { CORE_FIELDS } from './coreFields'
import { findCardType } from './findCardType'
import { getItemTypes } from './getItemTypes'
import type { FieldValue } from './types'

/**
 * Every field a card's types declare, primary type first and each name once, with the card's value or else the
 * field's default, as the CLI's `getFieldValues` lists them.
 */
export function getFieldValues(data: TaskData): FieldValue[] {
  const result: FieldValue[] = []
  const seen = new Set<string>()

  for (const name of getItemTypes(data).types) {
    for (const field of findCardType(name)?.fields ?? []) {
      if (seen.has(field.name)) continue

      seen.add(field.name)

      const stored = CORE_FIELDS.has(field.name) ? (data as Record<string, unknown>)[field.name] : data.fields?.[field.name]

      result.push({ field, type: name, value: (stored as FieldValue['value']) ?? field.default })
    }
  }

  return result
}
