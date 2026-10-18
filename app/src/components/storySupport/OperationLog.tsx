import { useSyncExternalStore, type CSSProperties } from 'react'
import { sentOperations, type SentOperations } from './fakeServe'

const STYLE: CSSProperties = {
  position: 'fixed',
  left: 280,
  top: 72,
  zIndex: 20,
  maxWidth: 520,
  padding: 'var(--space-3) var(--space-4)',
  borderRadius: 'var(--radius-md)',
  border: 'var(--border-width-default) solid var(--border-default)',
  background: 'var(--surface-background)',
  boxShadow: 'var(--shadow-raised)',
  color: 'var(--text-primary)',
  fontFamily: 'var(--font-data)',
  fontSize: 'var(--text-size-caption)',
}

const describe = (operation: SentOperations['operations'][number]) => {
  const { op, id, data } = operation

  if (op === 'setData' && data && typeof data === 'object') {
    const { label, status, who } = data as { label?: string; status?: string; who?: string }

    return `setData ${id} · status ${status}${who ? ` · who ${who}` : ''} · “${label}”`
  }

  return id ? `${op} ${id}` : op
}

/** Spike #102: the operations the stand-in server received, so a story shows each edit reaching `orion serve`. */
export function OperationLog() {
  const sent = useSyncExternalStore(sentOperations.subscribe, sentOperations.get)

  return (
    <aside style={STYLE} aria-label="Operations sent to orion serve">
      <strong>POST /api/operations</strong>
      {sent.length ? (
        <ol style={{ margin: 'var(--space-2) 0 0', paddingLeft: 'var(--space-5)' }}>
          {sent.slice(-4).map((entry) => (
            <li key={entry.revision}>
              <span style={{ color: 'var(--text-muted)' }}>r{entry.revision}</span> {entry.operations.map(describe).join('; ')}
            </li>
          ))}
        </ol>
      ) : (
        <p style={{ margin: 'var(--space-2) 0 0', color: 'var(--text-muted)' }}>Nothing sent yet. Edit a cell in the table.</p>
      )}
    </aside>
  )
}
