import { useEffect, useState } from 'react'

const API = '/api/editor'
let availability: Promise<boolean> | undefined

function canOpen(): Promise<boolean> {
  availability ??= fetch(API)
    .then(async (response) => response.ok && (await response.json()).available === true)
    .catch(() => false)

  return availability
}

export function OpenInVscode({ url }: { url: string }) {
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
      title="Open in VS Code"
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
      VS Code
    </button>
  )
}
