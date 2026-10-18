/** JSON with sorted keys, so two copies of the same data compare equal however their keys were added. */
export function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`

  if (value && typeof value === 'object') {
    const record = value as Record<string, unknown>
    const keys = Object.keys(record)
      .filter((key) => record[key] !== undefined)
      .sort()

    return `{${keys.map((key) => `${JSON.stringify(key)}:${stableJson(record[key])}`).join(',')}}`
  }

  return JSON.stringify(value) ?? 'null'
}
