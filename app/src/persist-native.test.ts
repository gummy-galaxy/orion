import { beforeEach, describe, expect, it, vi } from 'vitest'

const native = vi.hoisted(() => ({ invoke: vi.fn(), isTauri: vi.fn(() => true) }))
vi.mock('@tauri-apps/api/core', () => native)

import { createWorkspace, getWorkspaces, load, save, setActiveWorkspace } from './persist'

beforeEach(() => {
  native.invoke.mockReset()
  native.isTauri.mockReturnValue(true)
})

describe('native canvas persistence', () => {
  it('loads the selected live workspace through the native bridge', async () => {
    const doc = { version: 1, revision: 7, settings: { githubOwner: 'flipbook-labs' }, nodes: [], links: [] }
    native.invoke.mockResolvedValue(doc)
    expect(await load('ideas')).toEqual({ source: 'file', doc })
    expect(native.invoke).toHaveBeenCalledWith('orion_load', { workspace: 'ideas' })
  })

  it('saves with the same revision and workspace checks as the CLI', async () => {
    native.invoke.mockResolvedValue({ ok: true, revision: 8 })
    const result = await save('file', 7, { nodes: [], links: [], stickers: [] }, 'ideas')
    expect(result).toEqual({ ok: true, revision: 8 })
    expect(native.invoke).toHaveBeenCalledWith('orion_save', {
      workspace: 'ideas',
      baseRevision: 7,
      saved: { nodes: [], links: [], stickers: [], stickerLoadout: undefined },
    })
  })

  it('uses the shared workspace manifest', async () => {
    const list = { active: 'ideas', workspaces: [{ name: 'ideas', label: 'Ideas' }] }
    native.invoke.mockResolvedValue(list)
    expect(await getWorkspaces()).toEqual(list)
    expect(await setActiveWorkspace('ideas')).toEqual(list)
    expect(await createWorkspace('ideas', 'Ideas')).toEqual(list)
    expect(native.invoke.mock.calls.map(([command]) => command)).toEqual(['orion_workspaces', 'orion_set_active_workspace', 'orion_create_workspace'])
  })
})
