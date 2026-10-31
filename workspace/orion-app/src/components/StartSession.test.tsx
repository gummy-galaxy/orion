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
  attaches: true,
  repo: 'owner/orion',
  branch: 'agent/fix',
  place: 'checkout',
  folder: '/Users/me/git/orion-fix',
  problem: null,
}

const start = () => Promise.resolve()

test('offers each preset that fits and says where the agent opens', () => {
  const html = renderToStaticMarkup(<StartSession options={ready} start={start} />)

  expect(html).toContain('>Work on this card</button>')
  expect(html).toContain('>Resolve conflicts</button>')
  expect(html).toContain('Opens Claude Code in <b title="/Users/me/git/orion-fix">orion-fix</b>.')
  expect(html).not.toContain('disabled')
})

test('starts in the clone to make a worktree when the branch has no checkout', () => {
  const html = renderToStaticMarkup(<StartSession options={{ ...ready, place: 'clone', folder: '/Users/me/git/orion' }} start={start} />)

  expect(html).toContain('<b title="/Users/me/git/orion">orion</b> to make a worktree for agent/fix.')
})

test('starts with no folder, and says how to see the session on the card', () => {
  const html = renderToStaticMarkup(<StartSession options={{ ...ready, place: 'none', folder: null, attaches: false }} start={start} />)

  expect(html).toContain('Opens Claude Code, which asks where to work.')
  expect(html).toContain('Add a Claude Code source to see it on this card.')
  expect(html).not.toContain('disabled')
})
