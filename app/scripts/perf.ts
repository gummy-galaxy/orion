/// <reference lib="dom" />
/**
 * Compares the app's performance on this checkout against a base revision (origin/main by default).
 *
 *   npm run perf -- [--base <ref>] [--runs <n>] [--stories <id,id>] [--skip-bench] [--skip-render]
 *
 * Both sides run the harness from this checkout: the data benchmarks in src/perf, and the perf stories driven in
 * Chromium through Playwright. The report lands in .perf/report.md.
 */
import { execFileSync, spawnSync } from 'node:child_process'
import { cpSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, statSync, symlinkSync, writeFileSync } from 'node:fs'
import { createServer, type Server } from 'node:http'
import type { AddressInfo } from 'node:net'
import { tmpdir } from 'node:os'
import { dirname, extname, join, normalize, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs } from 'node:util'
import { chromium, type Browser, type Page } from 'playwright'

type Side = 'base' | 'head'
type Sample = Record<string, number>
type BenchResult = { p50: number; rme: number }
/** What the perf stories expose on the page, plus the frame gaps this script records there. */
type PerfWindow = Window & { orionPerf?: { commits: number; renderMs: number; reset: () => void }; perfFrames?: number[] }

const APP = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const OUT = join(APP, '.perf')
const HARNESS = ['src/perf', '.storybook']
const VIEWPORT = { width: 1440, height: 900 }
const IDLE_MS = 3000
const SETTLE_MS = 800
const SLOW_FRAME_MS = 33
const TRACE_CATEGORIES = ['devtools.timeline', 'disabled-by-default-devtools.timeline']
const MIME: Record<string, string> = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
}
/** Rows of the render report, in order, with how to read each one. */
const METRICS: [key: string, label: string, kind: 'count' | 'ms'][] = [
  ['commits', 'React commits', 'count'],
  ['renderMs', 'React render ms', 'ms'],
  ['frames', 'Frames drawn', 'count'],
  ['mainMs', 'Main thread busy ms', 'ms'],
  ['styleMs', 'Style ms', 'ms'],
  ['layoutMs', 'Layout ms', 'ms'],
  ['rasterMs', 'Raster ms', 'ms'],
  ['slowFrames', `Frames over ${SLOW_FRAME_MS} ms`, 'count'],
]
/** A change smaller than this reads as noise in the report. */
const NOISE = { count: 0.1, ms: 0.1 }

const { values: options } = parseArgs({
  options: {
    base: { type: 'string', default: 'origin/main' },
    runs: { type: 'string', default: '3' },
    // The 5,000-card story takes minutes per interaction today, so it's opt-in until the canvas scales.
    stories: { type: 'string', default: 'perf-canvas--cards-1000' },
    'skip-bench': { type: 'boolean', default: false },
    'skip-render': { type: 'boolean', default: false },
  },
})

const git = (...args: string[]) => execFileSync('git', args, { cwd: APP, encoding: 'utf8' }).trim()

function run(command: string, args: string[], cwd: string, env: NodeJS.ProcessEnv = {}) {
  const result = spawnSync(command, args, { cwd, stdio: ['ignore', 'pipe', 'inherit'], env: { ...process.env, ...env } })

  if (result.status !== 0) throw new Error(`${command} ${args.join(' ')} failed in ${cwd}`)
}

/** An unpacked copy of the base revision's app with this checkout's harness laid over it. */
function prepareBase(ref: string): { dir: string; sha: string } {
  const sha = git('rev-parse', ref)
  const root = join(tmpdir(), 'orion-perf', sha.slice(0, 12))
  const dir = join(root, 'app')

  if (!existsSync(join(dir, 'package.json'))) {
    const staging = `${root}.partial`
    const archive = execFileSync('git', ['archive', sha, 'app'], { cwd: git('rev-parse', '--show-toplevel'), maxBuffer: 1 << 30 })

    rmSync(staging, { recursive: true, force: true })
    mkdirSync(staging, { recursive: true })
    execFileSync('tar', ['-x', '-C', staging], { input: archive })
    rmSync(root, { recursive: true, force: true })
    renameSync(staging, root)
  }

  for (const path of HARNESS) {
    rmSync(join(dir, path), { recursive: true, force: true })
    cpSync(join(APP, path), join(dir, path), { recursive: true })
  }

  const modules = join(dir, 'node_modules')

  if (!existsSync(modules)) {
    const sameLock = readFileSync(join(dir, 'package-lock.json'), 'utf8') === readFileSync(join(APP, 'package-lock.json'), 'utf8')

    if (sameLock) symlinkSync(join(APP, 'node_modules'), modules, 'dir')
    else run('npm', ['ci', '--no-audit', '--no-fund', '--silent'], dir)
  }

  return { dir, sha }
}

function runBenchmarks(dir: string, side: Side): Map<string, BenchResult> {
  const file = join(OUT, side, 'bench.json')

  console.log(`Benchmarking ${side}…`)
  mkdirSync(dirname(file), { recursive: true })
  run(join(dir, 'node_modules/.bin/vitest'), ['bench', '--root', 'src', '--run', '--reporter=json', `--outputFile=${file}`], dir)

  type Report = {
    testResults: { assertionResults: { title: string; benchmarks?: { tasks: { name: string; latency: { p50: number; rme: number } }[] }[] }[] }[]
  }
  const report = JSON.parse(readFileSync(file, 'utf8')) as Report
  const results = new Map<string, BenchResult>()

  for (const test of report.testResults.flatMap((file) => file.assertionResults)) {
    for (const task of (test.benchmarks ?? []).flatMap((group) => group.tasks)) {
      results.set(`${test.title} › ${task.name}`, { p50: task.latency.p50, rme: task.latency.rme })
    }
  }

  return results
}

function buildStorybook(dir: string, side: Side): string {
  const out = join(OUT, side, 'storybook')

  console.log(`Building ${side} Storybook…`)
  run(join(dir, 'node_modules/.bin/storybook'), ['build', '-o', out, '--quiet'], dir, {
    ORION_PERF: '1',
    ORION_STORYBOOK: '1',
    STORYBOOK_DISABLE_TELEMETRY: '1',
  })

  return out
}

/** Serves a static build. Anything else 404s as plain text, so the app falls back to browser storage. */
function serve(dir: string): Promise<{ server: Server; url: string }> {
  const server = createServer((request, response) => {
    const path = normalize(decodeURIComponent(new URL(request.url ?? '/', 'http://x').pathname))
    const file = join(dir, path.endsWith('/') ? join(path, 'index.html') : path)

    if (!file.startsWith(dir) || !existsSync(file) || !statSync(file).isFile()) {
      response.writeHead(404, { 'content-type': 'text/plain' }).end('Not found')

      return
    }

    response.writeHead(200, { 'content-type': MIME[extname(file)] ?? 'application/octet-stream' }).end(readFileSync(file))
  })

  return new Promise((done) =>
    server.listen(0, '127.0.0.1', () => done({ server, url: `http://127.0.0.1:${(server.address() as AddressInfo).port}` })),
  )
}

type TraceEvent = { name: string; ph: string; pid: number; tid: number; dur?: number; args?: { name?: string } }

/** Totals from a Chromium trace: frames the page drew, and time on its main thread and raster workers. */
function readTrace(events: TraceEvent[]): Sample {
  const threads = new Map(
    events.filter((event) => event.ph === 'M' && event.name === 'thread_name').map((event) => [`${event.pid}:${event.tid}`, event.args?.name]),
  )
  const onMain = (event: TraceEvent) => threads.get(`${event.pid}:${event.tid}`) === 'CrRendererMain'
  const complete = events.filter((event) => event.ph === 'X')
  const total = (keep: (event: TraceEvent) => boolean) => complete.filter(keep).reduce((sum, event) => sum + (event.dur ?? 0), 0) / 1000

  return {
    frames: complete.filter((event) => event.name === 'Commit' && onMain(event)).length,
    mainMs: total((event) => event.name === 'RunTask' && onMain(event)),
    styleMs: total((event) => event.name === 'UpdateLayoutTree'),
    layoutMs: total((event) => event.name === 'Layout'),
    rasterMs: total((event) => event.name === 'RasterTask'),
  }
}

/** Times one interaction: React commits from the story's Profiler, browser work from a trace, and gaps between animation frames. */
async function measure(browser: Browser, page: Page, action: () => Promise<void>): Promise<Sample> {
  await page.evaluate(() => {
    const holder = window as PerfWindow
    const frames: number[] = []
    let last = performance.now()

    const tick = (now: number) => {
      frames.push(now - last)
      last = now

      if (holder.perfFrames === frames) requestAnimationFrame(tick)
    }

    holder.perfFrames = frames
    holder.orionPerf?.reset()
    requestAnimationFrame(tick)
  })

  await browser.startTracing(page, { categories: TRACE_CATEGORIES })
  await action()

  const trace = JSON.parse((await browser.stopTracing()).toString()) as { traceEvents: TraceEvent[] }
  const inPage = await page.evaluate(() => {
    const holder = window as PerfWindow
    const frames = holder.perfFrames ?? []

    holder.perfFrames = undefined

    return { frames, commits: holder.orionPerf?.commits ?? 0, renderMs: holder.orionPerf?.renderMs ?? 0 }
  })

  return {
    commits: inPage.commits,
    renderMs: inPage.renderMs,
    ...readTrace(trace.traceEvents),
    slowFrames: inPage.frames.filter((gap) => gap > SLOW_FRAME_MS).length,
  }
}

/** Centers of task cards fully inside the window, top-left first. */
async function visibleCards(page: Page): Promise<{ x: number; y: number }[]> {
  return page.evaluate(() =>
    [...document.querySelectorAll('.react-flow__node-task')]
      .map((node) => node.getBoundingClientRect())
      .filter((box) => box.top > 60 && box.left > 60 && box.bottom < innerHeight - 80 && box.right < innerWidth - 60)
      .sort((a, b) => a.top - b.top || a.left - b.left)
      .map((box) => ({ x: box.left + box.width / 2, y: box.top + box.height / 2 })),
  )
}

const wait = (ms: number) => new Promise<void>((done) => setTimeout(done, ms))

async function profileStory(browser: Browser, url: string, story: string): Promise<Record<string, Sample>> {
  const context = await browser.newContext({ viewport: VIEWPORT, deviceScaleFactor: 2 })
  const page = await context.newPage()
  const samples: Record<string, Sample> = {}
  const center = { x: VIEWPORT.width / 2, y: VIEWPORT.height / 2 }

  const started = Date.now()

  await page.goto(`${url}/iframe.html?id=${story}&viewMode=story`)
  await page.waitForSelector('.react-flow__node-task', { timeout: 120_000 })

  const firstCards = Date.now() - started

  await wait(SETTLE_MS)

  const loaded = await page.evaluate(() => {
    const holder = window as PerfWindow

    return { commits: holder.orionPerf?.commits ?? 0, renderMs: holder.orionPerf?.renderMs ?? 0 }
  })

  samples.load = { firstCardsMs: firstCards, ...loaded }
  samples.idle = await measure(browser, page, () => wait(IDLE_MS))

  await page.mouse.move(center.x, center.y)
  await wait(SETTLE_MS)

  samples.pan = await measure(browser, page, async () => {
    for (let step = 0; step < 40; step++) {
      await page.mouse.wheel(step < 20 ? 24 : -24, step < 20 ? 40 : -40)
      await wait(16)
    }

    await wait(SETTLE_MS)
  })

  samples.zoom = await measure(browser, page, async () => {
    await page.keyboard.down('Control')

    for (let step = 0; step < 30; step++) {
      await page.mouse.wheel(0, step < 15 ? -12 : 12)
      await wait(16)
    }

    await page.keyboard.up('Control')
    await wait(SETTLE_MS)
  })

  const cards = await visibleCards(page)

  samples.hover = await measure(browser, page, async () => {
    for (const card of cards.slice(0, 12)) {
      await page.mouse.move(card.x, card.y, { steps: 4 })
      await wait(80)
    }

    await wait(SETTLE_MS)
  })

  const target = cards[Math.min(3, cards.length - 1)]

  if (target) {
    samples.drag = await measure(browser, page, async () => {
      await page.mouse.move(target.x, target.y)
      await page.mouse.down()
      await page.mouse.move(target.x + 260, target.y + 140, { steps: 30 })
      await page.mouse.up()
      await wait(SETTLE_MS)
    })
  }

  await context.close()

  return samples
}

const median = (values: number[]) => {
  const sorted = [...values].sort((a, b) => a - b)
  const middle = Math.floor(sorted.length / 2)

  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

function medianSamples(runs: Record<string, Sample>[]): Record<string, Sample> {
  const result: Record<string, Sample> = {}

  for (const scenario of Object.keys(runs[0] ?? {})) {
    result[scenario] = {}

    for (const key of Object.keys(runs[0][scenario])) result[scenario][key] = median(runs.map((sample) => sample[scenario]?.[key] ?? 0))
  }

  return result
}

const format = (value: number | undefined, kind: 'count' | 'ms') =>
  value === undefined ? '–' : kind === 'count' ? String(Math.round(value)) : value < 10 ? value.toFixed(2) : value.toFixed(0)

/** "base → head", with the change when it's bigger than noise. A ⚠ marks a change for the worse. */
function compare(base: number | undefined, head: number | undefined, kind: 'count' | 'ms'): string {
  const text = `${format(base, kind)} → ${format(head, kind)}`

  if (base === undefined || head === undefined || base === head) return text

  const change = base === 0 ? Infinity : (head - base) / base

  if (Math.abs(change) < NOISE[kind] || (kind === 'count' && Math.abs(head - base) < 2) || (kind === 'ms' && Math.abs(head - base) < 0.5)) return text

  const percent = change === Infinity ? 'new' : `${change > 0 ? '+' : ''}${Math.round(change * 100)}%`

  return `${text} (${percent}${change > 0 ? ' ⚠' : ''})`
}

function benchTable(base: Map<string, BenchResult>, head: Map<string, BenchResult>): string {
  const rows = [...new Set([...base.keys(), ...head.keys()])].map((name) => {
    const before = base.get(name)
    const after = head.get(name)
    const noise = Math.max(NOISE.ms, ((before?.rme ?? 0) + (after?.rme ?? 0)) / 100)
    const change = before && after ? (after.p50 - before.p50) / before.p50 : undefined
    const verdict =
      change === undefined ? '' : change > noise ? `+${Math.round(change * 100)}% ⚠` : change < -noise ? `${Math.round(change * 100)}%` : ''

    return `| ${name} | ${format(before?.p50, 'ms')} | ${format(after?.p50, 'ms')} | ${verdict} |`
  })

  return ['| Benchmark (median ms) | Base | Head | Change |', '| --- | ---: | ---: | --- |', ...rows].join('\n')
}

function renderTable(story: string, base: Record<string, Sample>, head: Record<string, Sample>): string {
  const scenarios = Object.keys(head).filter((scenario) => scenario !== 'load')
  const load = `Load: first cards ${compare(base.load?.firstCardsMs, head.load?.firstCardsMs, 'ms')} ms, ${compare(base.load?.commits, head.load?.commits, 'count')} commits, ${compare(base.load?.renderMs, head.load?.renderMs, 'ms')} render ms.`
  const rows = METRICS.map(
    ([key, label, kind]) => `| ${label} | ${scenarios.map((scenario) => compare(base[scenario]?.[key], head[scenario]?.[key], kind)).join(' | ')} |`,
  )

  return [`### ${story}`, '', load, '', `| Metric | ${scenarios.join(' | ')} |`, `| --- |${scenarios.map(() => ' --- |').join('')}`, ...rows].join(
    '\n',
  )
}

async function main() {
  const runs = Number(options.runs)
  const stories = options.stories.split(',').filter(Boolean)
  const base = prepareBase(options.base)
  const dirs: Record<Side, string> = { base: base.dir, head: APP }
  const sections = [
    `# Performance: ${options.base} (${base.sha.slice(0, 7)}) → ${git('rev-parse', '--abbrev-ref', 'HEAD')} (${git('rev-parse', '--short', 'HEAD')})`,
  ]
  const raw: Record<string, unknown> = {}

  mkdirSync(OUT, { recursive: true })

  if (!options['skip-bench']) {
    const results = { base: runBenchmarks(dirs.base, 'base'), head: runBenchmarks(dirs.head, 'head') }

    raw.bench = { base: Object.fromEntries(results.base), head: Object.fromEntries(results.head) }
    sections.push('## Data benchmarks', benchTable(results.base, results.head))
  }

  if (!options['skip-render']) {
    const builds = { base: buildStorybook(dirs.base, 'base'), head: buildStorybook(dirs.head, 'head') }
    const servers = { base: await serve(builds.base), head: await serve(builds.head) }
    const browser = await chromium.launch()
    const collected: Record<Side, Record<string, Record<string, Sample>[]>> = { base: {}, head: {} }

    try {
      for (let index = 0; index < runs; index++) {
        // Alternating the order keeps a warming or throttling machine from favoring one side.
        const order: Side[] = index % 2 ? ['head', 'base'] : ['base', 'head']

        for (const side of order) {
          for (const story of stories) {
            console.log(`Profiling ${side} ${story} (run ${index + 1} of ${runs})…`)
            ;(collected[side][story] ??= []).push(await profileStory(browser, servers[side].url, story))
          }
        }
      }
    } finally {
      await browser.close()
      servers.base.server.close()
      servers.head.server.close()
    }

    raw.render = collected
    sections.push(
      '## Rendering',
      `Medians of ${runs} runs in headless Chromium at 2x scale. Idle waits ${IDLE_MS / 1000} s with motion on; the others pan, pinch-zoom, hover across cards, and drag one card.`,
      ...stories.map((story) => renderTable(story, medianSamples(collected.base[story]), medianSamples(collected.head[story]))),
    )
  }

  const report = sections.join('\n\n') + '\n'

  writeFileSync(join(OUT, 'report.md'), report)
  writeFileSync(join(OUT, 'raw.json'), JSON.stringify(raw, null, 2))
  console.log('\n' + report)
  console.log(`Saved to ${join(OUT, 'report.md')}`)
}

await main()
