import type { Tool } from '../components/Toolbar'
import { summarizeDurations } from './summarizeDurations'
import type { TelemetryEvent } from '../telemetry'

export type FeatureCounter = 'stickers_placed' | 'comments_left' | 'groups_created' | 'tidies' | 'pastes'
export type TimedMetric = 'pan_frame' | 'zoom_frame' | 'layout'

export type TelemetrySession = {
  /** Starts timing a newly chosen tool, ending the last one's time. */
  setTool: (tool: Tool) => void
  count: (counter: FeatureCounter) => void
  record: (metric: TimedMetric, durationMs: number) => void
  /** The stretch since the last call as `features_used` and `performance_summarized` events, after which the next stretch starts. */
  takeEvents: (size: { card_count: number; group_count: number }) => TelemetryEvent[]
}

/** Enough samples for a steady p95 over a stretch. Later ones still count toward sample_count. */
export const MAX_SAMPLES = 1000

const TOOL_PROPERTIES: Record<Tool, string> = {
  select: 'select_tool_ms',
  hand: 'pan_tool_ms',
  comment: 'comment_tool_ms',
  sticker: 'sticker_tool_ms',
}

const METRICS: TimedMetric[] = ['pan_frame', 'zoom_frame', 'layout']

/**
 * Gathers what one session of the app does, for usage telemetry: time in each tool, counts of what was made, and how
 * long frames and layouts took. It holds counts and durations only. Sending is the caller's.
 */
export function createTelemetrySession(now: () => number = () => performance.now()): TelemetrySession {
  let stretchStart = now()
  let tool: Tool = 'select'
  let toolSince = stretchStart
  let toolTime: Partial<Record<Tool, number>> = {}
  let counters: Partial<Record<FeatureCounter, number>> = {}
  let samples: Record<TimedMetric, number[]> = { pan_frame: [], zoom_frame: [], layout: [] }
  let sampleCounts: Record<TimedMetric, number> = { pan_frame: 0, zoom_frame: 0, layout: 0 }

  const endTool = (at: number) => {
    toolTime[tool] = (toolTime[tool] ?? 0) + (at - toolSince)
    toolSince = at
  }

  return {
    setTool(next) {
      if (next === tool) return

      endTool(now())
      tool = next
    },

    count(counter) {
      counters[counter] = (counters[counter] ?? 0) + 1
    },

    record(metric, durationMs) {
      sampleCounts[metric]++

      if (samples[metric].length < MAX_SAMPLES) samples[metric].push(durationMs)
    },

    takeEvents(size) {
      const at = now()

      endTool(at)

      const features: Record<string, number> = { session_ms: Math.round(at - stretchStart), ...counters }

      for (const [name, property] of Object.entries(TOOL_PROPERTIES)) features[property] = Math.round(toolTime[name as Tool] ?? 0)

      const events: TelemetryEvent[] = [{ name: 'features_used', properties: features }]

      for (const metric of METRICS) {
        const summary = summarizeDurations(samples[metric])

        if (summary) {
          events.push({
            name: 'performance_summarized',
            properties: {
              metric,
              sample_count: sampleCounts[metric],
              p50_ms: summary.p50,
              p95_ms: summary.p95,
              max_ms: summary.max,
              // Only these two: the backend refuses a property the catalog doesn't list for this event.
              card_count: size.card_count,
              group_count: size.group_count,
            },
          })
        }
      }

      stretchStart = at
      toolTime = {}
      counters = {}
      samples = { pan_frame: [], zoom_frame: [], layout: [] }
      sampleCounts = { pan_frame: 0, zoom_frame: 0, layout: 0 }

      return events
    },
  }
}
