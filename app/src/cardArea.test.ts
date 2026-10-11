import { describe, expect, it } from 'vitest'
import { getCardArea } from './cardArea'

describe('getCardArea', () => {
  it('reads the area from the words in a title', () => {
    expect(getCardArea('Add a trading card skin')).toBe('interface')
    expect(getCardArea('Keep rolling backups of the data file')).toBe('store')
    expect(getCardArea('Serve Orion data from the CLI with orion serve')).toBe('service')
    expect(getCardArea('Check Luau formatting with StyLua in CI')).toBe('process')
    expect(getCardArea('Ingest work from GitHub, Jira, and hop')).toBe('external')
    expect(getCardArea('Switch our docs to a Vitepress site')).toBe('actor')
    expect(getCardArea('Throwaway todos that clear themselves when done')).toBe('queue')
  })

  it('matches plurals, past tenses, and hyphenated words', () => {
    expect(getCardArea('Undo and redo canvas edits')).toBe('store')
    expect(getCardArea('Keep details readable when zoomed far out')).toBe('interface')
    expect(getCardArea('qa-in-studio: regression sweep')).toBe('external')
  })

  it('lets a more particular area win a tie over interface words', () => {
    expect(getCardArea('Move card source fields onto a list of refs')).toBe('store')
  })

  it('weighs the title over the note, and returns nothing without a match', () => {
    expect(getCardArea('Add a trading card skin', 'Reads the workspace file')).toBe('interface')
    expect(getCardArea('Bounties and traits')).toBeUndefined()
  })
})
