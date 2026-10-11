import { useEffect, useState } from 'react'

const API = '/api/merge'
/** How long the button waits for the confirming click before it settles back. */
const CONFIRM_MS = 4000
const LABEL = { idle: '', confirm: 'Merge', merging: 'Merging…', merged: 'Merged' }

/** Merges a ready pull request in two clicks, as long as GitHub still has the head commit the card shows. */
export function MergePullRequest({ url, head }: { url: string; head: string }) {
  const [step, setStep] = useState<keyof typeof LABEL>('idle')

  useEffect(() => {
    if (step !== 'confirm') return

    const timeout = window.setTimeout(() => setStep('idle'), CONFIRM_MS)

    return () => window.clearTimeout(timeout)
  }, [step])

  return (
    <button
      type="button"
      className={`merge-pull nodrag nopan is-${step}`}
      aria-label={step === 'confirm' ? 'Confirm merging this pull request' : 'Merge pull request'}
      title={step === 'confirm' ? 'Click again to merge' : 'Ready to merge'}
      disabled={step === 'merging' || step === 'merged'}
      onBlur={() => setStep((current) => (current === 'confirm' ? 'idle' : current))}
      onClick={(event) => {
        event.stopPropagation()

        if (step === 'idle') {
          setStep('confirm')

          return
        }

        setStep('merging')
        void fetch(API, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ url, head }),
        })
          .then(async (response) => {
            if (response.ok) {
              setStep('merged')

              return
            }

            const body = await response.json().catch(() => ({}))

            throw new Error(body.error || 'Could not merge this pull request')
          })
          .catch((error) => {
            setStep('idle')
            window.alert(String(error))
          })
      }}
    >
      <svg viewBox="0 0 16 16" width="12" height="12" aria-hidden="true">
        <circle cx="4.5" cy="3.5" r="1.75" />
        <circle cx="4.5" cy="12.5" r="1.75" />
        <circle cx="11.5" cy="9" r="1.75" />
        <path d="M4.5 5.25v5.5M4.5 5.25c0 2.5 2.5 3.75 5.25 3.75" />
      </svg>
      {LABEL[step] && <span>{LABEL[step]}</span>}
    </button>
  )
}
