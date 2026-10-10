import { describe, expect, it } from 'vitest'
import { editPullRef, getItemKind, getPrimaryRef, getPullRef, getPullRequestNumber, getTaskTag, getTaskUrl, type TaskData } from './model'

const task = (overrides: Partial<TaskData> = {}): TaskData => ({
  kind: 'task',
  label: 'Work',
  itemKind: 'step',
  status: 'todo',
  ...overrides,
})

describe('source refs', () => {
  it('uses the first linked ref for the tag and URL', () => {
    const data = task({
      repo: 'vocksel/orion',
      refs: [
        { source: 'hop', kind: 'branch', key: 'vocksel/orion@work' },
        { source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' },
      ],
    })

    expect(getPrimaryRef(data)).toBe(data.refs?.[1])
    expect(getTaskTag(data)).toBe('ORN-12')
    expect(getTaskUrl(data)).toBe('https://jira.example.com/browse/ORN-12')
  })

  it('falls back to the first ref, repository, and kind', () => {
    const unlinked = task({ refs: [{ source: 'hop', kind: 'branch', key: 'vocksel/orion@work' }] })

    expect(getTaskTag(unlinked)).toBe('vocksel/orion@work')
    expect(getTaskUrl(unlinked)).toBeNull()
    expect(getTaskTag(task({ repo: 'vocksel/orion' }))).toBe('vocksel/orion')
    expect(getTaskTag(task({ itemKind: 'gate' }))).toBe('gate')
    expect(getTaskTag(task())).toBe('step')
  })

  it('finds a pull ref and parses its number', () => {
    const data = task({
      refs: [
        { source: 'jira', kind: 'issue', key: 'ORN-12' },
        { source: 'github', kind: 'pull', key: 'github.example.com/Vocksel/Orion#42' },
      ],
    })

    expect(getPullRef(data)).toBe(data.refs?.[1])
    expect(getPullRequestNumber(getPullRef(data))).toBe(42)
    expect(getPullRequestNumber(data.refs?.[0])).toBeUndefined()
    expect(getPullRequestNumber({ source: 'github', kind: 'pull', key: 'vocksel/orion#bad' })).toBeUndefined()
    expect(getItemKind(data)).toBe('pr')
    expect(getItemKind(task({ repo: 'vocksel/orion' }))).toBe('placeholder')
    expect(getItemKind(task({ itemKind: 'gate', refs: data.refs }))).toBe('gate')
  })
})

describe('editPullRef', () => {
  const issue = { source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }

  it('adds a pull first and replaces the previous pull', () => {
    const data = task({ repo: 'vocksel/orion', refs: [issue, { source: 'github', kind: 'pull', key: 'vocksel/orion#41' }] })

    expect(editPullRef(data, 'vocksel/orion', 42)).toEqual({
      repo: 'vocksel/orion',
      itemKind: 'pr',
      refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#42', url: 'https://github.com/vocksel/orion/pull/42' }, issue],
    })
  })

  it('rewrites the pull on repository change and preserves the typed repository', () => {
    const data = task({ repo: 'vocksel/orion', refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#42' }, issue] })

    expect(editPullRef(data, 'Vocksel/Other ', 42)).toEqual({
      repo: 'Vocksel/Other ',
      itemKind: 'pr',
      refs: [{ source: 'github', kind: 'pull', key: 'Vocksel/Other#42', url: 'https://github.com/Vocksel/Other/pull/42' }, issue],
    })
  })

  it('preserves synced pull details when the key is unchanged ignoring case', () => {
    const existingPullRef = {
      source: 'gh-vocksel',
      kind: 'pull',
      key: 'Vocksel/Orion#42',
      url: 'https://github.example.com/Vocksel/Orion/pull/42',
      status: 'open',
      isDone: false,
      updatedAt: '2026-10-08T12:00:00Z',
      details: { checks: 'SUCCESS', branch: 'feature' },
    }
    const data = task({ repo: 'Vocksel/Orion', refs: [issue, existingPullRef] })
    const edited = editPullRef(data, 'vocksel/orion ', 42)

    expect(edited.repo).toBe('vocksel/orion ')
    expect(edited.refs?.[0]).toBe(existingPullRef)
    expect(edited.refs).toEqual([existingPullRef, issue])
    expect(edited.itemKind).toBe('pr')
  })

  it('clears the pull when the number or repository is cleared', () => {
    const data = task({ repo: 'vocksel/orion', refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#42' }, issue] })

    expect(editPullRef(data, 'vocksel/orion', undefined)).toEqual({ repo: 'vocksel/orion', refs: [issue], itemKind: 'placeholder' })
    expect(editPullRef(data, undefined, 42)).toEqual({ repo: undefined, refs: [issue], itemKind: 'step' })
    expect(editPullRef(task(), undefined, undefined)).toEqual({ repo: undefined, refs: undefined, itemKind: 'step' })
  })
})
