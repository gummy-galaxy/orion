import { useEffect, useState } from 'react'
import { MergeIcon } from './MergeIcon'

const API = '/api/merge'
/** How long the button waits for the confirming click before it settles back. */
const CONFIRM_MS = 4000
const LABEL = { idle: '', confirm: 'Merge', merging: 'Merging…', merged: 'Merged' }

/**
 * Merges a ready pull request in two clicks, as long as GitHub still has the head commit the card shows.
 * `idleLabel` names the button before the first click, and `nativeTitle` turns off the browser tooltip for
 * cards that draw their own.
 */
export function MergePullRequest({
  url,
  head,
  idleLabel = '',
  nativeTitle = true,
}: {
  url: string
  head: string
  idleLabel?: string
  nativeTitle?: boolean
}) {
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
      title={nativeTitle ? (step === 'confirm' ? 'Click again to merge' : 'Ready to merge') : undefined}
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
      <MergeIcon size={11} />
      {(step === 'idle' ? idleLabel : LABEL[step]) && <span>{step === 'idle' ? idleLabel : LABEL[step]}</span>}
    </button>
  )
}
