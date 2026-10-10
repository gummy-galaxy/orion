import { mergeDocs } from './merge'
import type { Saved } from './persist'

/** One edit, as the stored document before and after it. */
export type Step = { before: Saved; after: Saved }
export type History = { undo: Step[]; redo: Step[] }

export const HISTORY_LIMIT = 100

export const emptyHistory = (): History => ({ undo: [], redo: [] })

/** A new edit starts a new branch, so whatever was undone can't come back. */
export function record(history: History, step: Step, limit = HISTORY_LIMIT): History {
  return { undo: [...history.undo, step].slice(-limit), redo: [] }
}

/**
 * Applies the change from `from` to `to` on top of `current`. Everything else in
 * `current`, such as writes from the CLI or another window, stays, and where both
 * touched the same field, `current` wins.
 */
function carry(from: Saved, to: Saved, current: Saved): Saved {
  const { conflicts: _, ...doc } = mergeDocs(from, current, to)

  return doc
}

export function undo(history: History, current: Saved): { history: History; doc: Saved } | null {
  const step = history.undo.at(-1)

  if (!step) return null

  return { history: { undo: history.undo.slice(0, -1), redo: [...history.redo, step] }, doc: carry(step.after, step.before, current) }
}

export function redo(history: History, current: Saved): { history: History; doc: Saved } | null {
  const step = history.redo.at(-1)

  if (!step) return null

  return { history: { undo: [...history.undo, step], redo: history.redo.slice(0, -1) }, doc: carry(step.before, step.after, current) }
}
