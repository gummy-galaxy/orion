import type { Work } from '../derive'
import { COMPONENT_SHAPES, SHAPE_LABEL, getItemKind, type AppNode, type ComponentShape, type Link, type TaskData } from '../model'
import { TintSelect } from './TintSelect'
import { LinkList } from './LinkList'

/** A part of a system diagram: its name, where its code lives, what it does, and what it talks to. */
export function ComponentInspector({
  node,
  focus,
  doneEditing,
  work,
  map,
  update,
  remove,
  jumpTo,
  connections = true,
  links,
  addLink,
  removeLink,
  flipLink,
}: {
  node: AppNode
  /** Focuses the name, for a component that was just added. */
  focus: boolean
  doneEditing: () => void
  work: Work
  map: Map<string, AppNode>
  update: (id: string, patch: Partial<TaskData>) => void
  remove: () => void
  jumpTo: (id: string) => void
  /** Focus view draws connections beside the inspector. */
  connections?: boolean
  links: Link[]
  addLink: (from: string, to: string, kind: Link['kind']) => void
  removeLink: (id: string) => void
  flipLink: (id: string) => void
}) {
  const data = node.data as TaskData

  return (
    <div className="insp">
      <label htmlFor="c-label">Component</label>
      <input
        id="c-label"
        value={data.label}
        autoFocus={focus}
        placeholder="A service, app, or data store"
        onBlur={doneEditing}
        onKeyDown={(event) => event.key === 'Enter' && event.currentTarget.blur()}
        onChange={(event) => update(node.id, { label: event.target.value })}
      />
      <div className="grid2">
        <div>
          <label htmlFor="c-shape">Shape</label>
          <select
            id="c-shape"
            value={data.shape ?? 'service'}
            onChange={(event) => {
              const shape = event.target.value as ComponentShape

              update(node.id, { shape: shape === 'service' ? undefined : shape })
            }}
          >
            {COMPONENT_SHAPES.map((shape) => (
              <option key={shape} value={shape}>
                {SHAPE_LABEL[shape]}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="c-color">Color</label>
          <TintSelect id="c-color" value={data.color} inherit="Its group's" change={(color) => update(node.id, { color })} />
        </div>
      </div>
      <label htmlFor="c-repo">Repository</label>
      <input
        id="c-repo"
        value={data.repo ?? ''}
        placeholder="owner/name"
        onChange={(event) => update(node.id, { repo: event.target.value || undefined })}
      />
      <label htmlFor="c-note">Description</label>
      <textarea
        id="c-note"
        rows={3}
        value={data.note ?? ''}
        placeholder="What it does, shown under its name"
        onChange={(event) => update(node.id, { note: event.target.value || undefined })}
      />
      <p className="facts">Components are parts of a system. They have no status and never count as work.</p>
      {connections && (
        <LinkList node={node} work={work} nodeMap={map} links={links} jumpTo={jumpTo} addLink={addLink} removeLink={removeLink} flipLink={flipLink} />
      )}
      <div className="row">
        <button
          type="button"
          className="btn"
          onClick={() =>
            update(node.id, { itemKind: getItemKind({ ...data, itemKind: 'step' }), status: 'todo', shape: undefined, color: undefined })
          }
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
