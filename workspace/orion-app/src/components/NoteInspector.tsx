import type { SaveFields } from '../fields/types'
import type { AppNode, TaskData } from '../model'

export function NoteInspector({
  node,
  focus,
  onDoneEditing,
  update,
  saveFields,
  remove,
}: {
  node: AppNode
  focus: boolean
  onDoneEditing: () => void
  update: (id: string, patch: Partial<TaskData>) => void
  /** Saves fields the server checks, and resolves once it answers. */
  saveFields: SaveFields
  remove: () => void
}) {
  const data = node.data as TaskData

  return (
    <div className="insp">
      <label htmlFor="n-text">Note</label>
      <textarea
        id="n-text"
        rows={5}
        value={data.label}
        autoFocus={focus}
        placeholder="A detail to remember, or a plan that might become a pull request"
        onBlur={onDoneEditing}
        onChange={(event) => update(node.id, { label: event.target.value })}
      />
      <p className="facts">Notes pass blocking through but never count as work.</p>
      <div className="row">
        <button
          type="button"
          className="btn"
          onClick={() => void saveFields(node.id, { kind: 'step', status: 'todo' })}
        >
          Turn into a work item
        </button>
        <button type="button" className="btn danger" onClick={remove}>
          Delete
        </button>
      </div>
    </div>
  )
}
