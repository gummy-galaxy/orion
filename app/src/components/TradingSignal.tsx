import type { ReactNode } from 'react'
import type { Motion, Sticker } from '../skins/tradingFacts'
import { Tooltip } from './Tooltip'

/** Signals about a pull request's checks open its checks page; the rest open the pull request. */
const CHECK_SIGNALS: ReadonlySet<Sticker | Motion> = new Set(['failing', 'running', 'queued'])

/** A trading card signal. It links to GitHub when the card has a pull request, and otherwise only shows. */
export function TradingSignal({
  signal,
  className,
  hint,
  url,
  children,
}: {
  signal: Sticker | Motion
  className: string
  hint: string
  url?: string
  children: ReactNode
}) {
  if (!url) {
    return (
      <Tooltip label={hint}>
        <span className={className}>{children}</span>
      </Tooltip>
    )
  }

  const checks = CHECK_SIGNALS.has(signal)

  return (
    <Tooltip label={`${hint}. Click to open ${checks ? 'the checks' : 'the pull request'}.`}>
      <a className={`${className} trading-link nodrag nopan`} href={checks ? `${url}/checks` : url} target="_blank" rel="noreferrer">
        {children}
      </a>
    </Tooltip>
  )
}
