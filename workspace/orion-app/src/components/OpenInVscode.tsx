import { useEffect, useState } from 'react'
import vscodeIcon from '../assets/vscode.svg'

const API = '/api/editor'
let availability: Promise<boolean> | undefined

function canOpen(): Promise<boolean> {
  availability ??= fetch(API)
    .then(async (response) => response.ok && (await response.json()).available === true)
    .catch(() => false)

  return availability
}

/** `nativeTitle` turns off the browser tooltip for cards that draw their own. */
export function OpenInVscode({ url, nativeTitle = true }: { url: string; nativeTitle?: boolean }) {
  const [available, setAvailable] = useState(false)
  const [opening, setOpening] = useState(false)

  useEffect(() => {
    let mounted = true

    void canOpen().then((value) => {
      if (mounted) setAvailable(value)
    })

    return () => {
      mounted = false
    }
  }, [])

  if (!available) return null

  return (
    <button
      type="button"
      className="vscode-open nodrag nopan"
      aria-label="Open pull request in VS Code"
      title={nativeTitle ? 'Open in VS Code' : undefined}
      disabled={opening}
      onClick={(event) => {
        event.stopPropagation()
        setOpening(true)
        void fetch(API, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ url }),
        })
          .then(async (response) => {
            if (response.ok) return

            const body = await response.json().catch(() => ({}))

            throw new Error(body.error || 'Could not open this pull request in VS Code')
          })
          .catch((error) => window.alert(String(error)))
          .finally(() => setOpening(false))
      }}
    >
      <img src={vscodeIcon} alt="" draggable={false} />
    </button>
  )
}
