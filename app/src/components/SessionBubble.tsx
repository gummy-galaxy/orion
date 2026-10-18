import { getMessagePreview } from '../sessions/getMessagePreview'
import { SESSION_STATE_LABEL, type CardSession } from '../sessions/types'
import { SessionStateIcon } from './SessionStateIcon'
import { Tooltip } from './Tooltip'

/** The agent session on a card: its state, and the last thing it said, as a speech bubble over the card's art. */
export function SessionBubble({ session }: { session: CardSession }) {
  const label = SESSION_STATE_LABEL[session.state]

  return (
    <Tooltip label={`${session.title}: ${label}`}>
      <div className={`session-bubble session-bubble-${session.state}`}>
        <span className="session-bubble-state">
          <SessionStateIcon state={session.state} />
          {label}
        </span>
        {session.lastMessage && <p className="session-bubble-message">{getMessagePreview(session.lastMessage)}</p>}
      </div>
    </Tooltip>
  )
}
