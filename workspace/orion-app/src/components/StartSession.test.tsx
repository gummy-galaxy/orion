import { renderToStaticMarkup } from 'react-dom/server'
import { expect, test } from 'vitest'
import type { StartOptions } from '../sessions/types'
import { StartSession } from './StartSession'

const ready: StartOptions = {
  presets: [
    { id: 'work', label: 'Work on this card' },
    { id: 'resolve-conflicts', label: 'Resolve conflicts' },
  ],
  agent: 'Claude Code',
  folder: '/Users/me/git/orion-fix',
  problem: null,
}

const start = () => Promise.resolve()

test('offers each preset that fits and says where the agent opens', () => {
  const html = renderToStaticMarkup(<StartSession options={ready} start={start} />)

  expect(html).toContain('>Work on this card</button>')
  expect(html).toContain('>Resolve conflicts</button>')
  expect(html).toContain('Opens Claude Code in <b title="/Users/me/git/orion-fix">orion-fix</b>')
  expect(html).not.toContain('disabled')
})

test('says what is in the way and keeps the presets from starting', () => {
  const html = renderToStaticMarkup(
    <StartSession options={{ ...ready, folder: null, problem: 'No folder has agent/fix checked out.' }} start={start} />,
  )

  expect(html).toContain('No folder has agent/fix checked out.')
  expect(html.match(/disabled=""/g)).toHaveLength(2)
})
