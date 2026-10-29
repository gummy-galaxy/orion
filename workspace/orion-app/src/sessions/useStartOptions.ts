import { useEffect, useState } from 'react'
import { fetchStartOptions } from './fetchStartOptions'
import type { StartOptions } from './types'

/**
 * What starting a session from the card would do, asked again whenever `version` changes, such as when the
 * card's refs do. Null until the server answers, and when it can't.
 */
export function useStartOptions(workspace: string, cardId: string, version: string): StartOptions | null {
  const [loaded, setLoaded] = useState<{ key: string; options: StartOptions | null } | null>(null)
  const key = `${workspace}\n${cardId}\n${version}`

  useEffect(() => {
    let active = true

    void fetchStartOptions(workspace, cardId).then((options) => {
      if (active) setLoaded({ key, options })
    })

    return () => {
      active = false
    }
  }, [workspace, cardId, key])

  return loaded?.key === key ? loaded.options : null
}
