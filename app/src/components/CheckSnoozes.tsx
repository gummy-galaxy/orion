import { useAtom, useAtomValue } from 'jotai'
import { useState } from 'react'
import { changeSnoozes, findSnooze, isSnoozedOn, SNOOZE_LENGTHS, type CheckSnooze, type SnoozeLength } from '../checkSnoozes'
import type { FailedCheck } from '../model'
import { saveCheckSnooze } from '../persist'
import { checkSnoozesAtom, workspaceAtom } from '../state'

function snoozeLabel(snooze: CheckSnooze) {
  if (!snooze.until) return 'snoozed until it passes'

  return `snoozed until ${new Date(snooze.until).toLocaleString(undefined, { weekday: 'short', hour: 'numeric', minute: '2-digit' })}`
}

/**
 * The jobs failing on a card's pull request, each with a checkbox for whether it counts. Unchecking one snoozes that job
 * on every card in the repository, for as long as the length picked above the list.
 */
export function CheckSnoozes({ cardId, repo, failedChecks }: { cardId: string; repo: string; failedChecks: FailedCheck[] }) {
  const [snoozes, setSnoozes] = useAtom(checkSnoozesAtom)
  const workspace = useAtomValue(workspaceAtom)
  const [length, setLength] = useState<SnoozeLength>('pass')
  const snoozedCount = failedChecks.filter((check) => !check.optional && isSnoozedOn(snoozes, repo, check.name, cardId)).length

  const toggle = (name: string, snoozed: boolean) => {
    const next = changeSnoozes(snoozes, { repo, name, snoozed, length })

    // The server writes the change and the canvas reloads with it, so this only shows it sooner.
    setSnoozes(next.snoozes)
    void saveCheckSnooze(workspace, { repo, name, snoozed, ...(next.until ? { until: next.until } : {}) })
  }

  return (
    <details className="check-snoozes">
      <summary>
        {failedChecks.length} failing {failedChecks.length === 1 ? 'job' : 'jobs'}
        {snoozedCount > 0 && `, ${snoozedCount} snoozed`}
      </summary>
      <p className="check-snoozes-hint">Uncheck a job to snooze it on every card in {repo}.</p>
      <label className="check-snoozes-length">
        Snooze
        <select value={length} onChange={(event) => setLength(event.target.value as SnoozeLength)}>
          {SNOOZE_LENGTHS.map((option) => (
            <option key={option.id} value={option.id}>
              {option.label.toLowerCase()}
            </option>
          ))}
        </select>
      </label>
      <ul>
        {failedChecks.map((check) => {
          const snoozed = !check.optional && isSnoozedOn(snoozes, repo, check.name, cardId)
          const snooze = snoozed ? findSnooze(snoozes, repo, check.name) : undefined

          return (
            <li key={check.name}>
              <label>
                <input
                  type="checkbox"
                  checked={!check.optional && !snoozed}
                  disabled={check.optional}
                  onChange={(event) => toggle(check.name, !event.target.checked)}
                />
                <span className="check-snoozes-name">{check.name}</span>
                {check.optional ? (
                  <span className="check-snoozes-note">optional, doesn't count</span>
                ) : (
                  snooze && <span className="check-snoozes-note">{snoozeLabel(snooze)}</span>
                )}
              </label>
            </li>
          )
        })}
      </ul>
    </details>
  )
}
