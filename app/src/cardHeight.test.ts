import { TASK_HEIGHT, TASK_MAX_HEIGHT, TASK_WIDTH } from './geometry'
import { describe, expect, it } from 'vitest'
import { taskHeight } from './cardHeight'
import { type TaskData } from './model'

const card = (data: Partial<TaskData>): TaskData => ({ kind: 'task', label: 'Card', itemKind: 'step', status: 'todo', ...data })
const CLASSIC = { width: TASK_WIDTH, height: TASK_HEIGHT }
const TRADING = { width: 198, height: 285 }

describe('taskHeight', () => {
  it("estimates text it can't measure the way the CLI does, so both place notes the same", () => {
    // The same notes and heights as cli/src/graph/estimateTaskHeight.spec.luau.
    expect(taskHeight(card({ itemKind: 'note', label: 'a\nb\nc\nd\ne\nf' }), CLASSIC)).toBe(136)
    expect(taskHeight(card({ itemKind: 'note', label: 'word '.repeat(12) }), CLASSIC)).toBe(88)
    expect(taskHeight(card({ itemKind: 'note', label: 'x'.repeat(400) }), CLASSIC)).toBe(292)
  })

  it('keeps work cards one size however long their title', () => {
    expect(taskHeight(card({ label: 'A very long title '.repeat(10) }), CLASSIC)).toBe(TASK_HEIGHT)
  })

  it('grows notes and components with their text, up to a limit', () => {
    const short = taskHeight(card({ itemKind: 'note', label: 'Short' }), CLASSIC)
    const long = taskHeight(card({ itemKind: 'note', label: 'A sentence that goes on for a while. '.repeat(6) }), CLASSIC)
    const huge = taskHeight(card({ itemKind: 'note', label: 'Words '.repeat(500) }), CLASSIC)

    expect(short).toBe(TASK_HEIGHT)
    expect(long).toBeGreaterThan(short)
    expect(huge).toBe(TASK_MAX_HEIGHT)
    expect(
      taskHeight(card({ itemKind: 'component', label: 'Store', note: 'One lock for every write; revisions, migrations, and backups' }), CLASSIC),
    ).toBeGreaterThan(taskHeight(card({ itemKind: 'component', label: 'Store' }), CLASSIC))
  })

  it('leaves room for the shapes that take some of the card', () => {
    const data = { itemKind: 'component' as const, label: 'orion.json', note: 'One per workspace: nodes, links, and settings' }

    expect(taskHeight(card({ ...data, shape: 'store' }), CLASSIC)).toBeGreaterThan(taskHeight(card(data), CLASSIC))
  })

  it('keeps work cards and short notes at the skin size, and sizes components to their text', () => {
    expect(taskHeight(card({ label: 'Card' }), TRADING)).toBe(TRADING.height)
    expect(taskHeight(card({ itemKind: 'note', label: 'Short' }), TRADING)).toBe(TRADING.height)
    expect(taskHeight(card({ itemKind: 'component', label: 'Store' }), TRADING)).toBe(TASK_HEIGHT)
  })
})
