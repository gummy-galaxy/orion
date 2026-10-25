import { useEffect, useMemo, useState } from 'react'
import { fetchLog, getCardLog, type LogEntry } from './log'
import { onLogChange } from './persist'

/**
 * A card's log entries, newest first, kept current as other writers append. Null until the server
 * answers with a log, and whenever it has none to show.
 */
export function useCardLog(workspace: string, cardId: string): LogEntry[] | null {
  const [loaded, setLoaded] = useState<{ workspace: string; entries: LogEntry[] | null } | null>(null)

  useEffect(() => {
    let active = true
    let latest = 0

    // Answers can arrive out of order when appends come quickly, so only the newest request may land.
    const load = () => {
      const request = ++latest

      void fetchLog(workspace).then((entries) => {
        if (active && request === latest) setLoaded({ workspace, entries })
      })
    }

    load()

    const stop = onLogChange((changed) => {
      if (changed === workspace) load()
    })

    return () => {
      active = false
      stop()
    }
  }, [workspace])

  const entries = loaded?.workspace === workspace ? loaded.entries : null

  return useMemo(() => (entries ? getCardLog(entries, cardId) : null), [entries, cardId])
}
