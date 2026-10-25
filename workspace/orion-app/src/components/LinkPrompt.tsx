import { useEffect, useRef, useState } from 'react'

type Props = {
  x: number
  y: number
  /** Resolves once the link has a card, or rejects with a message to show. */
  submit: (url: string) => Promise<void>
  close: () => void
}

/** A field for pasting a pull request, issue, or Jira link to make a card from, opened where the canvas was right-clicked. */
export function LinkPrompt({ x, y, submit, close }: Props) {
  const ref = useRef<HTMLFormElement>(null)
  const [url, setUrl] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const away = (event: Event) => {
      if (!ref.current?.contains(event.target as Node)) close()
    }

    const key = (event: KeyboardEvent) => event.key === 'Escape' && close()

    window.addEventListener('pointerdown', away, true)
    window.addEventListener('keydown', key)

    return () => {
      window.removeEventListener('pointerdown', away, true)
      window.removeEventListener('keydown', key)
    }
  }, [close])

  const left = Math.min(x, window.innerWidth - 340)
  const top = Math.min(y, window.innerHeight - 120)

  return (
    <form
      ref={ref}
      className="link-prompt panel"
      style={{ left, top }}
      onSubmit={(event) => {
        event.preventDefault()

        const trimmed = url.trim()

        if (!trimmed || busy) return

        setBusy(true)
        setError(null)
        submit(trimmed)
          .then(close)
          .catch((failure: unknown) => {
            setBusy(false)
            setError(failure instanceof Error ? failure.message : 'Could not look up that link.')
          })
      }}
    >
      <label htmlFor="link-prompt-url">Create from link</label>
      <input
        id="link-prompt-url"
        type="url"
        autoFocus
        placeholder="Paste a pull request, issue, or Jira link"
        value={url}
        disabled={busy}
        onChange={(event) => setUrl(event.target.value)}
      />
      {busy && <span className="link-prompt-status">Looking it up…</span>}
      {error && (
        <span className="link-prompt-error" role="alert">
          {error}
        </span>
      )}
    </form>
  )
}
