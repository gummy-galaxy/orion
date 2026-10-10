import { describe, expect, it } from 'vitest'
import { taskHeight } from './cardSize'
import { TASK_HEIGHT, type TaskData } from './model'

const card = (data: Partial<TaskData>): TaskData => ({ kind: 'task', label: 'Card', itemKind: 'step', status: 'todo', ...data })

describe('taskHeight', () => {
  it('keeps work cards one size however long their title', () => {
    expect(taskHeight(card({ label: 'A very long title '.repeat(10) }))).toBe(TASK_HEIGHT)
  })

  it('grows notes and components with their text, up to a limit', () => {
    const short = taskHeight(card({ itemKind: 'note', label: 'Short' }))
    const long = taskHeight(card({ itemKind: 'note', label: 'A sentence that goes on for a while. '.repeat(6) }))
    const huge = taskHeight(card({ itemKind: 'note', label: 'Words '.repeat(500) }))

    expect(short).toBe(TASK_HEIGHT)
    expect(long).toBeGreaterThan(short)
    expect(huge).toBe(320)
    expect(
      taskHeight(card({ itemKind: 'component', label: 'Store', note: 'One lock for every write; revisions, migrations, and backups' })),
    ).toBeGreaterThan(taskHeight(card({ itemKind: 'component', label: 'Store' })))
  })

  it('leaves room for the shapes that take some of the card', () => {
    const data = { itemKind: 'component' as const, label: 'orion.json', note: 'One per workspace: nodes, links, and settings' }

    expect(taskHeight(card({ ...data, shape: 'store' }))).toBeGreaterThan(taskHeight(card(data)))
  })
})
