import { useEffect, useRef, useState, useSyncExternalStore, type RefObject } from 'react'
import { useStore } from '@xyflow/react'
import { getCompactZoom, setCompactZoom, subscribeCompactZoom, zoomLevel } from '../zoomLevel'
import { ProcessUsage } from './ProcessUsage'

export type MotionSettings = { arrows: boolean; glow: boolean; pauseWhileMoving: boolean }

type Sample = {
  fps: number
  worst: number
  slow: number
  /** Null where the browser doesn't report long tasks, such as WebKit. */
  longTasks: number | null
  longest: number
  nodes: number
  edges: number
  live: number
  glowing: number
  moving: boolean
}

const SAMPLE_MS = 500
/** A frame slower than this misses 60 fps by a full frame or more. */
const SLOW_FRAME_MS = 33

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
  const zoom = useStore((state) => state.transform[2])
  const breakpoint = useSyncExternalStore(subscribeCompactZoom, getCompactZoom)
  // The breakpoint input keeps what's typed, so a half-finished value like "0." isn't rewritten under the cursor.
  const [draft, setDraft] = useState<string | null>(null)
  const [sample, setSample] = useState<Sample | null>(null)
  const frames = useRef<number[]>([])

  useEffect(() => {
    let raf = 0
    let last = performance.now()
    let windowStart = last
    const tasks: number[] = []
    const observer = PerformanceObserver.supportedEntryTypes?.includes('longtask')
      ? new PerformanceObserver((list) => tasks.push(...list.getEntries().map((entry) => entry.duration)))
      : null

    observer?.observe({ type: 'longtask' })

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
          slow: deltas.filter((delta) => delta > SLOW_FRAME_MS).length,
          longTasks: observer ? tasks.length : null,
          longest: Math.round(Math.max(0, ...tasks)),
          nodes: root?.querySelectorAll('.react-flow__node').length ?? 0,
          edges: root?.querySelectorAll('.react-flow__edge').length ?? 0,
          live: root?.querySelectorAll('.react-flow__edge.e-live:not(.tr-e-dim) .react-flow__edge-path:not(.is-offscreen)').length ?? 0,
          glowing: root?.querySelectorAll('.card.st-active:not(.lens)').length ?? 0,
          moving: root?.hasAttribute('data-moving') ?? false,
        })
        tasks.length = 0
        windowStart = now
      }

      raf = requestAnimationFrame(tick)
    }

    raf = requestAnimationFrame(tick)

    return () => {
      cancelAnimationFrame(raf)
      observer?.disconnect()
    }
  }, [canvas])

  const toggle = (key: keyof MotionSettings) => setMotion({ ...motion, [key]: !motion[key] })
  const fpsClass = !sample ? '' : sample.fps >= 55 ? 'good' : sample.fps >= 30 ? 'fair' : 'poor'

  return (
    <div className="debug-bar" role="status">
      <span className={`debug-fps ${fpsClass}`}>{sample ? `${sample.fps} fps` : '… fps'}</span>
      <ProcessUsage />
      {sample && (
        <>
          <span title="Slowest frame in the last half second">worst {sample.worst} ms</span>
          <span title={`Frames slower than ${SLOW_FRAME_MS} ms in the last half second`}>slow {sample.slow}</span>
          <span>
            zoom {zoom.toFixed(2)} · {zoomLevel(zoom)}
          </span>
          <label title="Cards below this zoom draw compact, and related links stop drawing">
            compact below{' '}
            <input
              type="number"
              className="debug-breakpoint"
              min={0.01}
              max={2}
              step={0.01}
              value={draft ?? breakpoint.toFixed(2)}
              onChange={(event) => {
                setDraft(event.currentTarget.value)
                setCompactZoom(event.currentTarget.valueAsNumber)
              }}
              onBlur={() => setDraft(null)}
            />
            ×
          </label>
          <span title="Long tasks blocking the page in the last half second">
            {sample.longTasks === null ? 'long tasks n/a' : `long tasks ${sample.longTasks} · longest ${sample.longest} ms`}
          </span>
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
