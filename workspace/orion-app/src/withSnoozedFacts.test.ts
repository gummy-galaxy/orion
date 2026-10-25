import { expect, test } from 'vitest'
import type { SourceRef } from './model'
import { withSnoozedFacts } from './withSnoozedFacts'

const failing: SourceRef = {
  source: 'github',
  kind: 'pull',
  key: 'vocksel/orion#12',
  readiness: 'failing',
  checks: { state: 'failing', total: 6, finished: 6, failed: 1, failures: [{ name: 'docs' }] },
}

test('shows the snoozed facts in place of the ref’s own', () => {
  const checks = { state: 'passing' as const, total: 6, finished: 6, failed: 0, failures: [{ name: 'docs' }] }
  const ref = withSnoozedFacts(failing, { readiness: 'passing', checks, snoozed: [{ name: 'docs' }] })

  expect(ref.readiness).toBe('passing')
  expect(ref.checks).toEqual(checks)
  expect(ref.key).toBe('vocksel/orion#12')
})

test('keeps the ref as it is without snoozed facts', () => {
  expect(withSnoozedFacts(failing, undefined)).toBe(failing)
})
