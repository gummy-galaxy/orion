import { sharedValue, type BatchPatch } from '../batchEdit'
import { STATUS_CHOICES, WHO_CHOICES, type Status, type TaskData, type Who } from '../model'

type Props = {
  /** The work items in the selection. Notes and components have no status, so they're left out. */
  items: TaskData[]
  update: (patch: BatchPatch) => void
}

/** Status and whose move it is for a multi-selection, set on every work item in it at once. */
export function SelectionStatus({ items, update }: Props) {
  const status = sharedValue(items.map((item) => item.status))
  const who = sharedValue(items.map((item) => item.who))

  return (
    <section className="insp-section" aria-label="Status">
      <div className="grid2">
        <div>
          <label htmlFor="selection-status">Status</label>
          <select
            id="selection-status"
            value={status}
            onChange={(event) => update({ status: event.target.value as Status })}
          >
            {status === 'mixed' && (
              <option value="mixed" disabled>
                Mixed
              </option>
            )}
            {STATUS_CHOICES.map((choice) => (
              <option key={choice.value} value={choice.value}>
                {choice.label}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="selection-who">Whose move</label>
          <select
            id="selection-who"
            value={who ?? ''}
            onChange={(event) => update({ who: (event.target.value || undefined) as Who | undefined })}
          >
            {who === 'mixed' && (
              <option value="mixed" disabled>
                Mixed
              </option>
            )}
            <option value="">Not set</option>
            {WHO_CHOICES.map((choice) => (
              <option key={choice.value} value={choice.value}>
                {choice.label}
              </option>
            ))}
          </select>
        </div>
      </div>
      <p className="facts">
        Sets {items.length} work {items.length === 1 ? 'item' : 'items'}
      </p>
    </section>
  )
}
