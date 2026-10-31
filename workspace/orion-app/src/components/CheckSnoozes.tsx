import { useAtomValue } from 'jotai'
import { useState } from 'react'
import { SNOOZE_LENGTHS, type SnoozeLength } from '../checkSnoozes'
import type { SnoozedJob } from '../derive'
import { getSnoozeEnd } from '../getSnoozeEnd'
import type { FailedCheck } from '../model'
import { saveCheckSnooze } from '../persist'
import { workspaceAtom } from '../state'

function snoozeLabel(job: SnoozedJob) {
  if (!job.until) return 'snoozed until it passes'

  const until = new Date(job.until).toLocaleString(undefined, { weekday: 'short', hour: 'numeric', minute: '2-digit' })

  return `snoozed until ${until}`
}

/**
 * The jobs failing on a card's pull request, each with a checkbox for whether it counts. Unchecking one snoozes that
 * job on every card in the repository, for as long as the length picked above the list. Which jobs are snoozed on this
 * card comes from `orion serve`, with the snooze's end.
 */
export function CheckSnoozes({
  repo,
  failures,
  snoozed,
}: {
  repo: string
  failures: FailedCheck[]
  snoozed: SnoozedJob[]
}) {
  const workspace = useAtomValue(workspaceAtom)
  const [length, setLength] = useState<SnoozeLength>('pass')
  // Toggles show at once, until the server answers with a new list of snoozed jobs. They're dropped then, so they
  // can't come back if the list later returns to one they were made against.
  const [pending, setPending] = useState<{ base: SnoozedJob[]; changes: Record<string, boolean> }>()

  if (pending && pending.base !== snoozed) setPending(undefined)

  const changes = pending?.base === snoozed ? pending.changes : {}
  const isSnoozed = (name: string) => changes[name] ?? snoozed.some((job) => job.name === name)
  const snoozedCount = failures.filter((check) => !check.optional && isSnoozed(check.name)).length

  const toggle = (name: string, snooze: boolean) => {
    const until = snooze ? getSnoozeEnd(length) : undefined

    setPending({ base: snoozed, changes: { ...changes, [name]: snooze } })
    void saveCheckSnooze(workspace, { repo, name, snoozed: snooze, ...(until ? { until } : {}) })
  }

  return (
    <details className="check-snoozes">
      <summary>
        {failures.length} failing {failures.length === 1 ? 'job' : 'jobs'}
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
        {failures.map((check) => {
          const isCheckSnoozed = !check.optional && isSnoozed(check.name)
          const job = isCheckSnoozed ? snoozed.find((entry) => entry.name === check.name) : undefined

          return (
            <li key={check.name}>
              <label>
                <input
                  type="checkbox"
                  checked={!check.optional && !isCheckSnoozed}
                  disabled={check.optional}
                  onChange={(event) => toggle(check.name, !event.target.checked)}
                />
                <span className="check-snoozes-name">{check.name}</span>
                {check.optional ? (
                  <span className="check-snoozes-note">optional, doesn't count</span>
                ) : (
                  job && <span className="check-snoozes-note">{snoozeLabel(job)}</span>
                )}
              </label>
            </li>
          )
        })}
      </ul>
    </details>
  )
}
