import type { LogEntry } from '../log'
import { relativeTime } from '../model'
import { Markdown } from './Markdown'

/**
 * A card's running record, newest first. Renders nothing while there is no log to show, so a server without
 * one doesn't leave an empty section. Agent entries are marked, so a reader can tell them from a person's.
 */
export function Timeline({ entries }: { entries: LogEntry[] | null }) {
  if (!entries) return null

  return (
    <section className="insp-section" aria-label="Timeline">
      <h3 className="insp-heading">Timeline</h3>
      {entries.length === 0 ? (
        <p className="facts">Nothing logged yet.</p>
      ) : (
        <ol className="timeline">
          {entries.map((entry) => {
            const isAgent = entry.author.kind === 'agent'

            return (
              <li key={entry.id} className="timeline-entry">
                <div className="timeline-meta">
                  <span className={isAgent ? 'timeline-author is-agent' : 'timeline-author'}>
                    {entry.author.name}
                    {isAgent && <span className="timeline-kind">agent</span>}
                  </span>
                  <time dateTime={entry.time} title={new Date(entry.time).toLocaleString()}>
                    {relativeTime(entry.time)}
                  </time>
                </div>
                <Markdown source={entry.text} className="timeline-text" />
              </li>
            )
          })}
        </ol>
      )}
    </section>
  )
}
