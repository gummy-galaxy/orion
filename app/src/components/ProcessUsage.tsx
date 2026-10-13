import { useEffect, useState } from 'react'
import { inDesktop } from '../external'

/** One of the app's processes as the desktop shell reports it: CPU in percent of a core, memory in bytes. */
type ProcessSample = { name: string; cpu: number | null; memory: number }

const USAGE_MS = 1000

const megabytes = (bytes: number) => `${Math.round(bytes / 1048576)} MB`
const percent = (cpu: number | null) => (cpu === null ? '…' : `${cpu < 10 ? cpu.toFixed(1) : Math.round(cpu)}%`)

/** CPU and memory summed over the app, its server, and the WebKit processes drawing it, with each one in the tooltip. */
export function ProcessUsage() {
  const [usage, setUsage] = useState<ProcessSample[] | null>(null)

  useEffect(() => {
    if (!inDesktop()) return

    let stopped = false
    const poll = () =>
      void import('@tauri-apps/api/core')
        .then(({ invoke }) => invoke<ProcessSample[]>('process_usage'))
        .then((next) => {
          if (!stopped) setUsage(next)
        })
        .catch(() => {
          // An older shell without the command; the rest of the bar still works.
        })

    poll()
    const timer = setInterval(poll, USAGE_MS)

    return () => {
      stopped = true
      clearInterval(timer)
    }
  }, [])

  if (!usage?.length) return null

  const cpu = usage.some((entry) => entry.cpu === null) ? null : usage.reduce((sum, entry) => sum + (entry.cpu ?? 0), 0)
  const memory = usage.reduce((sum, entry) => sum + entry.memory, 0)
  const detail = usage.map((entry) => `${entry.name}: ${percent(entry.cpu)} CPU, ${megabytes(entry.memory)}`).join('\n')

  return (
    <span title={detail}>
      cpu {percent(cpu)} · mem {megabytes(memory)}
    </span>
  )
}
