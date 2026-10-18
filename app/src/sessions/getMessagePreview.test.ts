import { expect, test } from 'vitest'
import { getMessagePreview } from './getMessagePreview'

test('keeps link words and drops Markdown marks and line breaks', () => {
  expect(getMessagePreview('I opened **draft** PR [vocksel/orion#464](https://github.com/vocksel/orion/pull/464).\n\n- `capture.mjs`')).toBe(
    'I opened draft PR vocksel/orion#464. - capture.mjs',
  )
})
