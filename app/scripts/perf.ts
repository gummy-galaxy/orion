/// <reference lib="dom" />
/**
 * Compares the app's performance on this checkout against a base revision (origin/main by default).
 *
 *   npm run perf -- [--base <ref>] [--runs <n>] [--stories <id,id>] [--skip-bench] [--skip-render]
 *
 * Both sides run the harness from this checkout: the data benchmarks in src/perf, and the perf stories driven in
 * Chromium through Playwright. Each side runs `--runs` times, alternating which goes first. The report lands in
 * .perf/report.md.
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
import { buildReport, IDLE_MS, SLOW_FRAME_MS, type ReportInput, type Sample } from './perfReport.ts'

type Side = 'base' | 'head'
/** What the perf stories expose on the page, plus the frame gaps this script records there. */
type PerfWindow = Window & { orionPerf?: { commits: number; renderMs: number; reset: () => void }; perfFrames?: number[] }

const APP = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const OUT = join(APP, '.perf')
const HARNESS = ['src/perf', '.storybook']
const VIEWPORT = { width: 1440, height: 900 }
const SETTLE_MS = 800
const TRACE_CATEGORIES = ['devtools.timeline', 'disabled-by-default-devtools.timeline']
const MIME: Record<string, string> = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
}
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

const formatDuration = (ms: number) =>
  ms < 60_000 ? `${(ms / 1000).toFixed(1)} s` : `${Math.floor(ms / 60_000)} min ${Math.round((ms % 60_000) / 1000)} s`

/** Logs a step of the comparison and how long it took, so a slow step stands out in CI logs. */
async function timed<T>(label: string, work: () => T | Promise<T>): Promise<T> {
  const started = performance.now()

  console.log(`${label}…`)

  const result = await work()

  console.log(`  done in ${formatDuration(performance.now() - started)}`)

  return result
}

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

/** Median time per call for each benchmark, from one vitest process. */
function runBenchmarks(dir: string, side: Side, round: number): Map<string, number> {
  const file = join(OUT, side, `bench-${round}.json`)

  mkdirSync(dirname(file), { recursive: true })
  run(join(dir, 'node_modules/.bin/vitest'), ['bench', '--root', 'src', '--run', '--reporter=json', `--outputFile=${file}`], dir)

  type Report = {
    testResults: { assertionResults: { title: string; benchmarks?: { tasks: { name: string; latency: { p50: number } }[] }[] }[] }[]
  }
  const report = JSON.parse(readFileSync(file, 'utf8')) as Report
  const results = new Map<string, number>()

  for (const test of report.testResults.flatMap((file) => file.assertionResults)) {
    for (const task of (test.benchmarks ?? []).flatMap((group) => group.tasks)) results.set(`${test.title} › ${task.name}`, task.latency.p50)
  }

  return results
}

function buildStorybook(dir: string, side: Side): string {
  const out = join(OUT, side, 'storybook')

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

/** Sides in the order a run measures them. Alternating keeps a warming or throttling machine from favoring one side. */
const sideOrder = (index: number): Side[] => (index % 2 ? ['head', 'base'] : ['base', 'head'])

async function main() {
  const runs = Number(options.runs)
  const stories = options.stories.split(',').filter(Boolean)
  const started = performance.now()
  const base = await timed(`Preparing ${options.base}`, () => prepareBase(options.base))
  const dirs: Record<Side, string> = { base: base.dir, head: APP }
  const input: ReportInput = {
    base: { ref: options.base, sha: base.sha },
    head: { ref: process.env.GITHUB_HEAD_REF || git('rev-parse', '--abbrev-ref', 'HEAD'), sha: git('rev-parse', 'HEAD') },
  }
  const raw: Record<string, unknown> = {}

  mkdirSync(OUT, { recursive: true })

  if (!options['skip-bench']) {
    const bench: NonNullable<ReportInput['bench']> = { rounds: runs, base: {}, head: {} }

    for (let index = 0; index < runs; index++) {
      for (const side of sideOrder(index)) {
        const results = await timed(`Benchmarking ${side} (round ${index + 1} of ${runs})`, () => runBenchmarks(dirs[side], side, index))

        for (const [name, p50] of results) (bench[side][name] ??= []).push(p50)
      }
    }

    input.bench = bench
    raw.bench = bench
  }

  if (!options['skip-render']) {
    const builds = {
      base: await timed('Building base Storybook', () => buildStorybook(dirs.base, 'base')),
      head: await timed('Building head Storybook', () => buildStorybook(dirs.head, 'head')),
    }
    const servers = { base: await serve(builds.base), head: await serve(builds.head) }
    const browser = await chromium.launch()
    const collected: Record<Side, Record<string, Record<string, Sample>[]>> = { base: {}, head: {} }

    try {
      for (let index = 0; index < runs; index++) {
        for (const side of sideOrder(index)) {
          for (const story of stories) {
            const samples = await timed(`Profiling ${side} ${story} (run ${index + 1} of ${runs})`, () =>
              profileStory(browser, servers[side].url, story),
            )

            ;(collected[side][story] ??= []).push(samples)
          }
        }
      }
    } finally {
      await browser.close()
      servers.base.server.close()
      servers.head.server.close()
    }

    input.render = {
      runs,
      stories: Object.fromEntries(stories.map((story) => [story, { base: collected.base[story], head: collected.head[story] }])),
    }
    raw.render = collected
  }

  const report = buildReport(input)

  writeFileSync(join(OUT, 'report.md'), report)
  writeFileSync(join(OUT, 'raw.json'), JSON.stringify(raw, null, 2))
  console.log('\n' + report)
  console.log(`Saved to ${join(OUT, 'report.md')} after ${formatDuration(performance.now() - started)}`)
}

await main()
