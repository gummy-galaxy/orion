import { useState, type FormEvent } from 'react'
import { relativeTime } from '../model'
import { SESSION_STATE_LABEL, type CardSession, type SessionTurn } from '../sessions/types'
import { CompanionStar } from './CompanionStar'
import { Markdown } from './Markdown'
import { SessionStateIcon } from './SessionStateIcon'

type Props = {
  session: CardSession
  /** Null while the transcript loads, or when it can't be read. */
  turns: SessionTurn[] | null
  onClose: () => void
  now?: number
}

/**
 * The companion's chat with the selected card's agent session: its last few turns, read from the agent's own
 * transcript, and a box for a follow-up. Sending isn't built in this spike, so a message stays here as a draft.
 */
export function CompanionChat({ session, turns, onClose, now }: Props) {
  const [draft, setDraft] = useState('')
  const [unsent, setUnsent] = useState<string[]>([])
  const sessionId = session.key.replace(/^claude:/, '')

  const send = (event: FormEvent) => {
    event.preventDefault()

    const text = draft.trim()

    if (!text) return

    setUnsent((current) => [...current, text])
    setDraft('')
  }

  return (
    <section className={`companion-chat companion-chat-${session.state} nodrag nopan nowheel`} aria-label={`Chat with ${session.title}`}>
      <header className="companion-chat-header">
        <span className="companion-chat-avatar" aria-hidden="true">
          <CompanionStar face />
        </span>
        <div className="companion-chat-heading">
          <h2>{session.title}</h2>
          <span className="companion-chat-state">
            <SessionStateIcon state={session.state} />
            {SESSION_STATE_LABEL[session.state]}
            {session.updatedAt && ` · ${relativeTime(session.updatedAt, now)}`}
            {' · Claude Code'}
          </span>
        </div>
        <button type="button" className="companion-chat-close" aria-label="Close chat" onClick={onClose}>
          ×
        </button>
      </header>
      <ol className="companion-chat-turns">
        {turns === null && <li className="companion-chat-empty">Reading the transcript…</li>}
        {turns?.length === 0 && <li className="companion-chat-empty">Nothing said yet.</li>}
        {turns?.map((turn, i) => (
          <li key={i} className={`companion-chat-turn is-${turn.role}`}>
            <Markdown source={turn.text} />
          </li>
        ))}
        {unsent.map((text, i) => (
          <li key={`unsent-${i}`} className="companion-chat-turn is-you is-unsent">
            <Markdown source={text} />
            <span className="companion-chat-unsent">Not sent: sending isn't built in this spike</span>
          </li>
        ))}
      </ol>
      {session.state === 'waiting' && (
        <p className="companion-chat-notice">It stopped on something only you can answer, such as a permission prompt. Finish it where it runs.</p>
      )}
      {session.isLive && session.state !== 'waiting' && (
        <p className="companion-chat-notice">This session is still open in Claude Code. Sending from here could collide with it.</p>
      )}
      <form className="companion-chat-composer" onSubmit={send}>
        <textarea
          value={draft}
          placeholder="Reply to the session"
          rows={2}
          onChange={(event) => setDraft(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter' && !event.shiftKey) send(event)
          }}
        />
        <button type="submit" disabled={!draft.trim()} title={`Would run: claude -p --resume ${sessionId}`}>
          Send
        </button>
      </form>
    </section>
  )
}
