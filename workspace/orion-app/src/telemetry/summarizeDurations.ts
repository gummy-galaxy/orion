export type DurationSummary = { count: number; p50: number; p95: number; max: number }

const round = (value: number) => Math.round(value * 100) / 100

/** The nearest-rank percentile of samples already sorted ascending. */
const percentile = (sorted: readonly number[], fraction: number) => sorted[Math.max(0, Math.ceil(fraction * sorted.length) - 1)]

/** Summarizes durations in milliseconds as their median, 95th percentile, and slowest, rounded to a hundredth, the way the server does. */
export function summarizeDurations(samples: readonly number[]): DurationSummary | null {
  if (samples.length === 0) return null

  const sorted = [...samples].sort((a, b) => a - b)

  return { count: sorted.length, p50: round(percentile(sorted, 0.5)), p95: round(percentile(sorted, 0.95)), max: round(sorted[sorted.length - 1]) }
}
