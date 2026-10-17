import { isWork, type AppNode, type ClusterData, type Link, type TaskData } from '../model'

/** One link's label, kind, and ends, shown when the link is clicked. */
export function LinkInspector({
  link,
  map,
  focus,
  doneEditing,
  update,
  flip,
  remove,
  jumpTo,
}: {
  link: Link
  map: Map<string, AppNode>
  /** Focuses the label, for a link opened to be labeled. */
  focus: boolean
  doneEditing: () => void
  update: (id: string, patch: Partial<Pick<Link, 'label'>>) => void
  flip: (id: string) => void
  remove: () => void
  jumpTo: (id: string) => void
}) {
  const labelOf = (id: string) => {
    const node = map.get(id)

    return (node?.data as TaskData | ClusterData | undefined)?.label || 'Untitled'
  }

  return (
    <div className="insp">
      <span className="label-text">Link</span>
      <p className="link-ends">
        <button type="button" className="link" onClick={() => jumpTo(link.from)}>
          {labelOf(link.from)}
        </button>
        <span aria-hidden="true">{link.kind === 'blocks' ? '→' : '⋯'}</span>
        <button type="button" className="link" onClick={() => jumpTo(link.to)}>
          {labelOf(link.to)}
        </button>
      </p>
      <label htmlFor="l-label">Label</label>
      <input
        id="l-label"
        value={link.label ?? ''}
        placeholder="What it carries, like HTTP"
        autoFocus={focus}
        onBlur={(event) => {
          const label = event.target.value.trim()

          if (label !== (link.label ?? '')) update(link.id, { label: label || undefined })

          doneEditing()
        }}
        onKeyDown={(event) => event.key === 'Enter' && event.currentTarget.blur()}
        onChange={(event) => update(link.id, { label: event.target.value || undefined })}
      />
      {/* Links between work block; links that touch a component only show the way something flows. */}
      {isWork(map.get(link.from)) && isWork(map.get(link.to)) && (
        <p className="facts">{link.kind === 'blocks' ? 'Blocking: the second waits on the first.' : 'Related: drawn faintly and never blocks.'}</p>
      )}
      <div className="row">
        <button type="button" className="btn" onClick={() => flip(link.id)}>
          {link.kind === 'blocks' ? 'Make it related' : 'Make it blocking'}
        </button>
        <button type="button" className="btn danger" onClick={remove}>
          Remove link
        </button>
      </div>
    </div>
  )
}
