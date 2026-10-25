export function EmptyCanvas({ addNote }: { addNote: () => void }) {
  return (
    <div className="panel empty-canvas" role="status">
      <strong>Nothing here yet</strong>
      <p>
        Add work with <code>orion card create &lt;title&gt;</code>, or connect GitHub, Jira, or hop with <code>orion source add</code> and run{' '}
        <code>orion ingest</code>.
      </p>
      <button type="button" className="btn" onClick={addNote}>
        Add a note <kbd>N</kbd>
      </button>
    </div>
  )
}
