/**
 * Turns a perf comparison into Markdown that leads with what got slower. A colored callout gives the verdict, a table
 * lists only the changes beyond noise, and the full measurements sit in collapsed sections below. An emoji leads each
 * heading and verdict so the comment reads at a glance.
 */
export type Sample = Record<string, number>
/** The device Chromium drew with, and whether it composited on a GPU rather than in software. */
export type Renderer = { device: string; gpu: boolean }
export type ReportInput = {
  base: { ref: string; sha: string }
  head: { ref: string; sha: string }
  /** Median time per call for each benchmark, one per round on each side. */
  bench?: { rounds: number; base: Record<string, number[]>; head: Record<string, number[]> }
  /** Samples per story and scenario, one per run on each side. */
  render?: {
    runs: number
    renderer?: Renderer
    stories: Record<string, { base: Record<string, Sample>[]; head: Record<string, Sample>[] }>
  }
}

type Kind = 'count' | 'ms'
type Verdict = 'worse' | 'better' | 'same'
type Metric = { key: string; label: string; kind: Kind; paced?: boolean; neutral?: boolean }
type Row = { name: string; where: string; base?: number; head?: number; kind: Kind; change?: number; verdict: Verdict }

export const IDLE_MS = 3000
export const SLOW_FRAME_MS = 33

/** Frames a machine that keeps up draws while idle, at 60 Hz. */
const IDLE_FRAMES = (IDLE_MS / 1000) * 60
/** A change smaller than this reads as noise, even when every run agrees. */
const NOISE = 0.1
/** A change for the worse at least this large gets the louder mark. */
const LARGE = 0.25
/**
 * Rows of the rendering tables, in order. Paced rows only mean something when the machine keeps up with the display,
 * and neutral rows are shown without a verdict because more isn't better or worse on its own.
 */
const METRICS: Metric[] = [
  { key: 'commits', label: 'React commits', kind: 'count' },
  { key: 'renderMs', label: 'React render time', kind: 'ms' },
  { key: 'mainMs', label: 'Main thread time', kind: 'ms' },
  { key: 'styleMs', label: 'Style time', kind: 'ms' },
  { key: 'layoutMs', label: 'Layout time', kind: 'ms' },
  { key: 'rasterMs', label: 'Raster time', kind: 'ms', paced: true },
  { key: 'gpuMs', label: 'GPU time', kind: 'ms', paced: true },
  { key: 'slowFrames', label: `Frames over ${SLOW_FRAME_MS} ms`, kind: 'count', paced: true },
  { key: 'frames', label: 'Frames drawn', kind: 'count', paced: true, neutral: true },
]
/** What the perf story does in each scenario, as the report names it. */
const SCENARIOS: Record<string, string> = {
  load: 'Loading',
  idle: 'Idle',
  pan: 'Panning',
  zoom: 'Zooming',
  hover: 'Hovering',
  drag: 'Dragging',
}
const LOAD_METRICS: Metric[] = [
  { key: 'firstCardsMs', label: 'Time to first cards', kind: 'ms' },
  { key: 'commits', label: 'React commits', kind: 'count' },
  { key: 'renderMs', label: 'React render time', kind: 'ms' },
]

const format = (value: number | undefined, kind: Kind) =>
  value === undefined ? '–' : kind === 'count' ? String(Math.round(value)) : value < 10 ? value.toFixed(2) : Math.round(value).toLocaleString('en-US')

const unit = (kind: Kind) => (kind === 'ms' ? ' ms' : '')

const median = (values: number[]) => {
  const sorted = [...values].sort((a, b) => a - b)
  const middle = Math.floor(sorted.length / 2)

  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

/** How far a side's runs stray from each other, as a fraction of their median. */
const spread = (values: number[]) => {
  const middle = median(values)

  return middle === 0 ? 0 : (Math.max(...values) - Math.min(...values)) / middle
}

const scenarioName = (scenario: string) => SCENARIOS[scenario] ?? scenario

const percent = (change: number) => (change === Infinity ? 'new' : `${change > 0 ? '+' : '−'}${Math.abs(Math.round(change * 100))}%`)

/** 🔴 for a large change for the worse, 🟠 for a smaller one, 🟢 for a change for the better. */
const mark = (row: Row) => (row.verdict === 'worse' ? ((row.change ?? 0) >= LARGE ? '🔴' : '🟠') : row.verdict === 'better' ? '🟢' : '')

/**
 * Compares the medians of each side's runs. A change reads as noise unless it's larger than both `NOISE` and how far
 * the runs on each side disagree, so a measurement that swings from run to run needs a bigger change to count.
 * Rendering totals also ignore differences of a frame or two or under half a millisecond; benchmarks skip that floor
 * because many of them take well under a millisecond per call.
 */
function judge(baseRuns: number[], headRuns: number[], kind: Kind, { neutral = false, floor = true } = {}) {
  if (!baseRuns.length || !headRuns.length) return { base: undefined, head: undefined, verdict: 'same' as const }

  const base = median(baseRuns)
  const head = median(headRuns)

  if (base === head) return { base, head, verdict: 'same' as const }

  const change = base === 0 ? Infinity : (head - base) / base
  const noise = Math.max(NOISE, spread(baseRuns) + spread(headRuns))
  const tiny = floor && ((kind === 'count' && Math.abs(head - base) < 2) || (kind === 'ms' && Math.abs(head - base) < 0.5))
  const small = Math.abs(change) < noise || tiny

  if (neutral || small) return { base, head, change, verdict: 'same' as const }

  return { base, head, change, verdict: change > 0 ? ('worse' as const) : ('better' as const) }
}

/** "base → head", followed by the mark and change when it's beyond noise. */
function cell(row: Row): string {
  const text = `${format(row.base, row.kind)} → ${format(row.head, row.kind)}`

  return row.verdict === 'same' || row.change === undefined ? text : `${text} ${mark(row)} ${percent(row.change)}`
}

function table(header: string[], align: string[], rows: string[][]): string {
  return [`| ${header.join(' | ')} |`, `| ${align.join(' | ')} |`, ...rows.map((row) => `| ${row.join(' | ')} |`)].join('\n')
}

function details(summary: string, body: string[]): string {
  return ['<details>', `<summary>${summary}</summary>`, '', ...body, '', '</details>'].join('\n')
}

/** Counts a set of rows for a section summary, such as "18 measured · 🔴 1 slower". */
function tally(rows: Row[]): string {
  const worse = rows.filter((row) => row.verdict === 'worse').length
  const better = rows.filter((row) => row.verdict === 'better').length
  const parts = [`${rows.length} measured`]

  if (worse) parts.push(`${rows.some((row) => mark(row) === '🔴') ? '🔴' : '🟠'} ${worse} slower`)

  if (better) parts.push(`🟢 ${better} faster`)

  if (!worse && !better) parts.push('all within noise')

  return parts.join(' · ')
}

function benchSection(bench: NonNullable<ReportInput['bench']>): { rows: Row[]; text: string } {
  const names = [...new Set([...Object.keys(bench.base), ...Object.keys(bench.head)])]
  const rows = names.map((full): Row => {
    const [canvas, name] = full.includes(' › ') ? full.split(' › ') : ['', full]
    const where = canvas.replace(/\d{4,}/, (count) => Number(count).toLocaleString('en-US'))

    return { name: `\`${name}\``, where, kind: 'ms', ...judge(bench.base[full] ?? [], bench.head[full] ?? [], 'ms', { floor: false }) }
  })
  const text = details(`🧮 <b>Data benchmarks</b> · ${tally(rows)}`, [
    `Median time per call over generated canvases, then the median of ${bench.rounds} rounds on each side.`,
    '',
    table(
      ['Benchmark', 'Canvas', 'Base → head (ms)'],
      ['---', '---', '---'],
      rows.map((row) => [row.name, row.where, cell(row)]),
    ),
  ])

  return { rows, text }
}

function storySection(
  story: string,
  runs: number,
  base: Record<string, Sample>[],
  head: Record<string, Sample>[],
  label: string,
  renderer?: Renderer,
) {
  const scenarios = Object.keys(head[0] ?? {}).filter((scenario) => scenario !== 'load')
  const values = (samples: Record<string, Sample>[], scenario: string, key: string) => samples.flatMap((sample) => sample[scenario]?.[key] ?? [])
  // A machine that can't keep up with the display drops frames instead of doing more work, so paced rows would
  // measure how far behind it fell rather than what changed.
  const idleFrames = Math.min(...[base, head].map((samples) => median(values(samples, 'idle', 'frames')) || IDLE_FRAMES))
  const saturated = idleFrames < IDLE_FRAMES * 0.9
  const metrics = METRICS.filter((metric) => !saturated || !metric.paced)

  const row = (metric: Metric, scenario: string): Row => ({
    name: metric.label,
    where: label ? `${scenarioName(scenario)} · ${label}` : scenarioName(scenario),
    kind: metric.kind,
    ...judge(values(base, scenario, metric.key), values(head, scenario, metric.key), metric.kind, { neutral: metric.neutral }),
  })

  const load = LOAD_METRICS.map((metric) => row(metric, 'load'))
  const grid = metrics.map((metric) => scenarios.map((scenario) => row(metric, scenario)))
  const rows = [...load, ...grid.flat()]
  const body = [
    `Medians of ${runs} runs in headless Chromium at 2x scale${renderer ? `, drawn ${renderer.gpu ? 'on' : 'in software by'} \`${renderer.device}\`` : ''}. Idle waits ${IDLE_MS / 1000} s with motion on; the others pan, pinch-zoom, hover across cards, and drag one card.`,
    '',
    table(
      ['Loading', 'Base → head'],
      ['---', '---'],
      load.map((item) => [item.name + (item.kind === 'ms' ? ' (ms)' : ''), cell(item)]),
    ),
    '',
    table(
      ['Interaction', ...scenarios.map(scenarioName)],
      ['---', ...scenarios.map(() => '---')],
      metrics.map((metric, index) => [metric.label + (metric.kind === 'ms' ? ' (ms)' : ''), ...grid[index].map(cell)]),
    ),
  ]

  return { rows, saturated, idleFrames, text: details(`🎨 <b>Rendering: ${story}</b> · ${tally(rows)}`, body) }
}

/** Lists changes beyond noise, largest first. */
function changeTable(rows: Row[]): string {
  return table(
    ['', 'Measurement', 'Where', 'Base', 'Head', 'Change'],
    [':-:', '---', '---', '---:', '---:', '---:'],
    rows.map((row) => [
      mark(row),
      row.name,
      row.where,
      format(row.base, row.kind) + unit(row.kind),
      format(row.head, row.kind) + unit(row.kind),
      `**${percent(row.change ?? 0)}**`,
    ]),
  )
}

export function buildReport(input: ReportInput): string {
  const sections: { rows: Row[]; text: string }[] = []
  const notes: string[] = []

  if (input.bench) sections.push(benchSection(input.bench))

  if (input.render) {
    const stories = Object.entries(input.render.stories)

    for (const [story, { base, head }] of stories) {
      const label = stories.length > 1 ? story.replace(/^perf-canvas--/, '') : ''
      const section = storySection(story, input.render.runs, base, head, label, input.render.renderer)

      sections.push(section)

      if (section.saturated) {
        notes.push(
          `This machine drew ${Math.round(section.idleFrames)} of ${IDLE_FRAMES} frames while idle${label ? ` in ${label}` : ''}, so raster time and frame counts are left out. Run \`npm run perf\` locally to compare them.`,
        )
      }
    }
  }

  if (input.render?.renderer && !input.render.renderer.gpu) {
    notes.push('Chromium had no GPU on this machine and drew in software, so raster and GPU time measure the CPU.')
  }

  const rows = sections.flatMap((section) => section.rows)
  const worse = rows.filter((row) => row.verdict === 'worse').sort((a, b) => (b.change ?? 0) - (a.change ?? 0))
  const better = rows.filter((row) => row.verdict === 'better').sort((a, b) => (a.change ?? 0) - (b.change ?? 0))
  const large = worse.filter((row) => mark(row) === '🔴').length
  const plural = (count: number, word: string) => `${count} ${word}${count === 1 ? '' : 's'}`
  const within = rows.length - worse.length - better.length
  const counts = [worse.length && `${worse.length} slower`, better.length && `${better.length} faster`, within && `${within} within noise`]
  const callout = large
    ? [
        '> [!CAUTION]',
        `> 🐢 **${plural(worse.length, 'measurement')} got slower**${worse.length === 1 ? '' : large === worse.length ? ', all' : `, ${large} of them`} by ${LARGE * 100}% or more.`,
      ]
    : worse.length
      ? [
          '> [!WARNING]',
          `> 🐌 **${plural(worse.length, 'measurement')} got a little slower**, by less than ${LARGE * 100}%. Small changes can be noise, so see whether ${worse.length === 1 ? 'it repeats' : 'they repeat'} on the next run.`,
        ]
      : better.length
        ? ['> [!TIP]', `> 🚀 **Nothing got slower, and ${plural(better.length, 'measurement')} got faster.** Nice!`]
        : ['> [!TIP]', `> 🧘 **Smooth sailing.** Every measurement is within noise of \`${input.base.ref}\`.`]
  const lines = [
    '## ⏱️ Performance',
    '',
    `Comparing \`${input.head.ref}\` (${input.head.sha.slice(0, 7)}) with \`${input.base.ref}\` (${input.base.sha.slice(0, 7)}) across ${plural(rows.length, 'measurement')}: ${
      within === rows.length ? 'all within noise' : counts.filter(Boolean).join(', ')
    }.`,
    '',
    ...callout,
  ]

  if (worse.length) lines.push('', '### 🐢 Slower', '', changeTable(worse))

  if (better.length) lines.push('', '### 🚀 Faster', '', changeTable(better))

  for (const note of notes) lines.push('', '> [!NOTE]', `> ${note}`)

  lines.push('', '### 🔬 All measurements', '', ...sections.flatMap((section) => [section.text, '']))

  return lines.join('\n').trimEnd() + '\n'
}
