import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

// The header is scaled to keep its text legible, so in a narrow group it gets less room than its contents need. Its
// ring and name must hold their size there instead of flexing down to nothing.
const css = readFileSync(new URL('./index.css', import.meta.url), 'utf8')

describe('cluster header', () => {
  it('keeps the ring and the name from shrinking away in a narrow group', () => {
    expect(css).toMatch(/\.cluster-head > \* \{\s*flex-shrink: 0;/)
    expect(css).toMatch(/\.cluster-head strong \{\s*flex-shrink: 1;\s*min-width: 4em;/)
  })
})
