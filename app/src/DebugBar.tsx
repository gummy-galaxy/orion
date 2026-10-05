import { useEffect, useRef, useState, type RefObject } from 'react'
import { useStore } from '@xyflow/react'
import { inDesktop } from './external'

export type MotionSettings = { arrows: boolean; glow: boolean; pauseWhileMoving: boolean }

type Sample = { fps: number; worst: number; slow: number; nodes: number; edges: number; live: number; glowing: number; moving: boolean }
/** One of the app's processes as the desktop shell reports it: CPU in percent of a core, memory in bytes. */
type ProcessUsage = { name: string; cpu: number | null; memory: number }

const SAMPLE_MS = 500
/** A frame slower than this misses 60 fps by a full frame or more. */
const SLOW_FRAME_MS = 33
const USAGE_MS = 1000

const megabytes = (bytes: number) => `${Math.round(bytes / 1048576)} MB`
const percent = (cpu: number | null) => (cpu === null ? '…' : `${cpu < 10 ? cpu.toFixed(1) : Math.round(cpu)}%`)

/** CPU and memory summed over the app and the WebKit processes drawing it, with each one in the tooltip. */
function Usage() {
  const [usage, setUsage] = useState<ProcessUsage[] | null>(null)
  useEffect(() => {
    if (!inDesktop()) return
    let stopped = false
    const poll = () =>
      void import('@tauri-apps/api/core')
        .then(({ invoke }) => invoke<ProcessUsage[]>('process_usage'))
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
  const cpu = usage.some((p) => p.cpu === null) ? null : usage.reduce((sum, p) => sum + (p.cpu ?? 0), 0)
  const memory = usage.reduce((sum, p) => sum + p.memory, 0)
  const detail = usage.map((p) => `${p.name}: ${percent(p.cpu)} CPU, ${megabytes(p.memory)}`).join('\n')
  return (
    <span title={detail}>
      cpu {percent(cpu)} · mem {megabytes(memory)}
    </span>
  )
}

/** Bottom bar with frame timing and what's animating, for chasing down sluggish panning. */
export function DebugBar({
  canvas,
  motion,
  setMotion,
  close,
}: {
  canvas: RefObject<HTMLDivElement | null>
  motion: MotionSettings
  setMotion: (next: MotionSettings) => void
  close: () => void
}) {
  const zoom = useStore((s) => s.transform[2])
  const [sample, setSample] = useState<Sample | null>(null)
  const frames = useRef<number[]>([])

  useEffect(() => {
    let raf = 0
    let last = performance.now()
    let windowStart = last
    const tick = (now: number) => {
      frames.current.push(now - last)
      last = now
      if (now - windowStart >= SAMPLE_MS) {
        const deltas = frames.current
        frames.current = []
        const root = canvas.current
        setSample({
          fps: Math.round((deltas.length * 1000) / (now - windowStart)),
          worst: Math.round(Math.max(0, ...deltas)),
          slow: deltas.filter((d) => d > SLOW_FRAME_MS).length,
          nodes: root?.querySelectorAll('.react-flow__node').length ?? 0,
          edges: root?.querySelectorAll('.react-flow__edge').length ?? 0,
          live: root?.querySelectorAll('.react-flow__edge.e-live').length ?? 0,
          glowing: root?.querySelectorAll('.card.st-active:not(.lens)').length ?? 0,
          moving: root?.hasAttribute('data-moving') ?? false,
        })
        windowStart = now
      }
      raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [canvas])

  const toggle = (key: keyof MotionSettings) => setMotion({ ...motion, [key]: !motion[key] })
  const fpsClass = !sample ? '' : sample.fps >= 55 ? 'good' : sample.fps >= 30 ? 'fair' : 'poor'

  return (
    <div className="debug-bar" role="status">
      <span className={`debug-fps ${fpsClass}`}>{sample ? `${sample.fps} fps` : '… fps'}</span>
      <Usage />
      {sample && (
        <>
          <span title="Slowest frame in the last half second">worst {sample.worst} ms</span>
          <span title={`Frames slower than ${SLOW_FRAME_MS} ms in the last half second`}>slow {sample.slow}</span>
          <span>zoom {zoom.toFixed(2)}</span>
          <span>nodes {sample.nodes}</span>
          <span>
            edges {sample.edges} · animated {sample.live}
          </span>
          <span>glowing {sample.glowing}</span>
          {sample.moving && <span className="debug-moving">moving</span>}
        </>
      )}
      <span className="debug-toggles">
        <label>
          <input type="checkbox" checked={motion.arrows} onChange={() => toggle('arrows')} /> Arrow motion
        </label>
        <label>
          <input type="checkbox" checked={motion.glow} onChange={() => toggle('glow')} /> Glow
        </label>
        <label>
          <input type="checkbox" checked={motion.pauseWhileMoving} onChange={() => toggle('pauseWhileMoving')} /> Pause while moving
        </label>
        <button type="button" className="debug-close" onClick={close} aria-label="Hide the debug bar" title="Hide the debug bar">
          ×
        </button>
      </span>
    </div>
  )
}
