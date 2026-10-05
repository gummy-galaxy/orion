import { describe, expect, it } from 'vitest'
import type { TaskData } from './model'
import { attachSource, detachSource, driver, itemKindFor, migrateTask, ordered, parseSource, primaryLink, taskTag } from './sources'

const task = (extra: Record<string, unknown> = {}): TaskData =>
  ({ kind: 'task', label: 'Work', itemKind: 'step', status: 'todo', ...extra }) as TaskData

describe('sources', () => {
  it('carries legacy fields over the way the CLI does', () => {
    const data = migrateTask(
      task({
        itemKind: 'pr',
        repo: 'flipbook',
        pr: 12,
        branch: 'agent/ship',
        github: { state: 'OPEN', url: 'https://github.com/flipbook-labs/flipbook/pull/12' },
        jira: { key: 'ABC-1', status: 'In Progress', statusCategory: 'indeterminate', type: 'Task' },
        sources: ['gh-flipbook', 'jira'],
      }),
    )
    expect('repo' in data || 'github' in data || 'jira' in data).toBe(false)
    expect(ordered(data).map((s) => [s.kind, s.via])).toEqual([
      ['jira', 'jira'],
      ['github-pr', 'gh-flipbook'],
    ])
    expect(taskTag(data)).toBe('ABC-1')
    expect(driver(data)?.number).toBe(12)
    expect(itemKindFor(data)).toBe('pr')
    expect(migrateTask(data)).toBe(data)
  })

  it('treats a repository alone as an expected pull request', () => {
    const data = migrateTask(task({ itemKind: 'placeholder', repo: 'app' }))
    expect(data.sources).toEqual([{ kind: 'github-pr', repo: 'app' }])
    expect(data.itemKind).toBe('placeholder')
  })

  it('parses URLs and short forms', () => {
    expect(parseSource('https://github.com/Roblox/lua-apps/pull/49723', 'Roblox')).toEqual({ kind: 'github-pr', repo: 'lua-apps', number: 49723 })
    expect(parseSource('https://github.com/Roblox/foundation/releases/tag/Foundation%401.112.0', 'Roblox')).toEqual({
      kind: 'github-release',
      repo: 'foundation',
      tag: 'Foundation@1.112.0',
    })
    expect(parseSource('https://roblox.atlassian.net/browse/uiblox-5440', 'Roblox')).toMatchObject({ kind: 'jira', key: 'UIBLOX-5440' })
    expect(parseSource('https://roblox.slack.com/archives/C1/p2', 'Roblox').kind).toBe('slack')
    expect(parseSource('https://github.com/Roblox/uiblox/tree/v0.2.282', 'Roblox').kind).toBe('url')
    expect(parseSource('UIBLOX-5305', 'Roblox')).toEqual({ kind: 'jira', key: 'UIBLOX-5305' })
    expect(parseSource('vocksel/orion#4', 'Roblox', 'github-issue')).toEqual({ kind: 'github-issue', repo: 'vocksel/orion', number: 4 })
    expect(parseSource('uiblox@v0.2.285', 'Roblox')).toEqual({ kind: 'github-release', repo: 'uiblox', tag: 'v0.2.285' })
    expect(parseSource('lua-apps:agent/font', 'Roblox')).toEqual({ kind: 'hop', repo: 'lua-apps', branch: 'agent/font' })
    expect(() => parseSource('https://user:secret@github.com/a/b/pull/1', 'Roblox')).toThrow()
  })

  it('stacks pull requests on a ticket and lets the topmost open one drive', () => {
    let data = task()
    const apply = (patch: Partial<TaskData>) => (data = { ...data, ...patch })
    apply(attachSource(data, { kind: 'github-pr', repo: 'app' }))
    apply(attachSource(data, { kind: 'jira', key: 'ABC-2', url: 'https://example.atlassian.net/browse/ABC-2' }))
    apply(attachSource(data, { kind: 'github-pr', repo: 'app', number: 5 }))
    expect(data.sources?.length).toBe(2)
    expect(data.itemKind).toBe('pr')
    expect(primaryLink(data, 'Roblox')?.tag).toBe('ABC-2')
    apply(attachSource(data, { kind: 'github-pr', repo: 'app', number: 6 }))
    data = {
      ...data,
      sources: data.sources?.map((s) =>
        s.kind === 'github-pr' ? { ...s, state: { state: s.number === 5 ? 'OPEN' : 'MERGED' } } : s,
      ) as TaskData['sources'],
    }
    expect(driver(data)?.number).toBe(5)
    apply(detachSource(data, { kind: 'github-pr', repo: 'app', number: 5 }))
    expect(driver(data)?.number).toBe(6)
  })
})
