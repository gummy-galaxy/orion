import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { emptyHistory, record, redo as redoStep, undo as undoStep, type History } from './history'
import { compactDoc, fingerprint, type Saved } from './persist'

/** Changes this close together, such as keystrokes or a tween's frames, are one step. */
const SETTLE_MS = 300

type Baseline = { doc: Saved; print: string }

const baselineOf = (doc: Saved): Baseline => {
  const compact = compactDoc(doc)

  return { doc: compact, print: fingerprint(compact) }
}

/**
 * Records the canvas's own edits as steps once they settle, and takes them back or
 * replays them on top of whatever the document holds now. Writes from elsewhere
 * arrive through `rebase`, so they never become steps of their own.
 */
export function useUndo({
  doc,
  busy,
  getDoc,
  apply,
}: {
  doc: Saved
  /** While true, such as mid-drag, changes keep collecting into the step in progress. */
  busy: boolean
  getDoc: () => Saved
  /** Shows a document and returns what the canvas now holds. */
  apply: (doc: Saved) => Saved
}) {
  const history = useRef<History>(emptyHistory())
  const baseline = useRef<Baseline>(baselineOf(doc))
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const options = useRef({ getDoc, apply })
  const [counts, setCounts] = useState({ undo: 0, redo: 0 })

  useLayoutEffect(() => {
    options.current = { getDoc, apply }
  })

  const update = useCallback((next: History) => {
    history.current = next
    setCounts({ undo: next.undo.length, redo: next.redo.length })
  }, [])

  const commit = useCallback(() => {
    clearTimeout(timer.current)
    const current = baselineOf(options.current.getDoc())

    if (current.print === baseline.current.print) return

    update(record(history.current, { before: baseline.current.doc, after: current.doc }))
    baseline.current = current
  }, [update])

  useEffect(() => {
    if (busy) return

    timer.current = setTimeout(commit, SETTLE_MS)

    return () => clearTimeout(timer.current)
  }, [doc.nodes, doc.links, doc.stickers, doc.stickerLoadout, busy, commit])

  /** Takes in a document written elsewhere after keeping any edit still settling. */
  const rebase = useCallback(
    (next: Saved) => {
      commit()
      baseline.current = baselineOf(next)
    },
    [commit],
  )

  /** Starts over, as when another workspace opens. */
  const reset = useCallback(
    (next: Saved) => {
      clearTimeout(timer.current)
      update(emptyHistory())
      baseline.current = baselineOf(next)
    },
    [update],
  )

  const move = useCallback(
    (step: typeof undoStep) => {
      commit()
      const result = step(history.current, baseline.current.doc)

      if (!result) return

      update(result.history)
      baseline.current = baselineOf(options.current.apply(result.doc))
    },
    [commit, update],
  )

  const undo = useCallback(() => move(undoStep), [move])
  const redo = useCallback(() => move(redoStep), [move])

  return { undo, redo, canUndo: counts.undo > 0, canRedo: counts.redo > 0, rebase, reset }
}
