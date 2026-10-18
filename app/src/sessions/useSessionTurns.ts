import { useEffect, useState } from 'react'
import { fetchSessionTurns } from './fetchSessionTurns'
import type { SessionTurn } from './types'

const REFRESH_MS = 5000

/** A session's recent turns while its chat is open, read again every few seconds. Null until the server answers. */
export function useSessionTurns(workspace: string, key: string | undefined): SessionTurn[] | null {
  const [loaded, setLoaded] = useState<{ key: string; turns: SessionTurn[] | null } | null>(null)

  useEffect(() => {
    if (!key) return

    let active = true

    const load = () => {
      void fetchSessionTurns(workspace, key).then((turns) => {
        if (active) setLoaded({ key, turns })
      })
    }

    load()

    const timer = setInterval(load, REFRESH_MS)

    return () => {
      active = false
      clearInterval(timer)
    }
  }, [workspace, key])

  return loaded && loaded.key === key ? loaded.turns : null
}
