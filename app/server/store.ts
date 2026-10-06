import {
  constants,
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  unlinkSync,
  watch,
  writeFileSync,
} from 'node:fs'
import { execFile } from 'node:child_process'
import type { IncomingMessage } from 'node:http'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { promisify } from 'node:util'
import type { Plugin } from 'vite'

/**
 * Serves orion.json to the app during development. The CLI takes the same
 * mkdir lock and writes the same way, so either side can edit while the other
 * is open, and every change is announced to open pages.
 */

const FILE = 'orion.json'
const LOCK = 'orion.lock'
const BACKUPS = 'backups'
const DAY_MS = 24 * 60 * 60 * 1000
const DAILY_DAYS = 30
const LOCK_TIMEOUT_MS = 5000
const STALE_LOCK_SECONDS = 30
const API = '/api/orion'
const SYNC_API = '/api/sync'
const WORKSPACES_API = '/api/workspaces'
const WORKSPACES_FILE = 'workspaces.json'
const SYNC_INTERVAL_MS = 5 * 60 * 1000
const SYNC_THROTTLE_MS = 60 * 1000
const execFileAsync = promisify(execFile)
export const CHANGED_EVENT = 'orion:changed'

type SyncStatus = { state: 'idle' | 'running' | 'error' | 'unavailable'; lastRun?: string; message?: string }

type Doc = { version: number; revision: number; settings: { githubOwner: string }; nodes: unknown[]; links: unknown[] }
type Workspace = { name: string; label: string }
type WorkspaceList = { active: string; workspaces: Workspace[] }
let workspaceSequence = 0

export function dataDir() {
  const configured = process.env.ORION_DATA_DIR
  return configured ? resolve(configured) : join(homedir(), 'Library', 'Application Support', 'Orion')
}

function isValidWorkspace(name: unknown): name is string {
  return typeof name === 'string' && /^[a-z0-9-]+$/.test(name)
}

function getWorkspaceDir(root: string, name: string) {
  return name === 'default' ? root : join(root, 'workspaces', name)
}

function getWorkspaces(root: string): WorkspaceList {
  const file = join(root, WORKSPACES_FILE)
  if (!existsSync(file)) return { active: 'default', workspaces: [{ name: 'default', label: 'Default' }] }
  const value = JSON.parse(readFileSync(file, 'utf8')) as WorkspaceList
  if (!Array.isArray(value.workspaces)) throw new Error(`invalid workspace list at ${file}`)
  const entries: Workspace[] = [{ name: 'default', label: 'Default' }]
  for (const entry of value.workspaces) {
    if (!isValidWorkspace(entry.name) || typeof entry.label !== 'string' || !entry.label) throw new Error(`invalid workspace in ${file}`)
    if (entry.name === 'default') entries[0] = entry
    else if (!entries.some((known) => known.name === entry.name)) entries.push(entry)
  }
  const active = value.active ?? 'default'
  if (!entries.some((entry) => entry.name === active)) throw new Error(`unknown workspace: ${active}`)
  return { active, workspaces: entries }
}

function writeWorkspaces(root: string, list: WorkspaceList) {
  mkdirSync(root, { recursive: true })
  const file = join(root, WORKSPACES_FILE)
  workspaceSequence += 1
  const temporary = `${file}.tmp.${process.pid}.${workspaceSequence}`
  writeFileSync(temporary, JSON.stringify(list, null, 2))
  renameSync(temporary, file)
}

function knownWorkspace(list: WorkspaceList, name: unknown): asserts name is string {
  if (!isValidWorkspace(name)) throw new Error(`invalid workspace name: ${String(name)}`)
  if (!list.workspaces.some((entry) => entry.name === name)) throw new Error(`unknown workspace: ${name}`)
}

function read(dir: string): Doc | null {
  const file = join(dir, FILE)
  return existsSync(file) ? (JSON.parse(readFileSync(file, 'utf8')) as Doc) : null
}

const nowSeconds = () => Math.floor(Date.now() / 1000)
const pause = (ms: number) => new Promise((done) => setTimeout(done, ms))

async function acquire(dir: string) {
  const lockPath = join(dir, LOCK)
  const ownerPath = join(lockPath, 'owner')
  const deadline = Date.now() + LOCK_TIMEOUT_MS
  for (;;) {
    try {
      mkdirSync(lockPath)
      writeFileSync(ownerPath, `${process.pid} ${nowSeconds()}`)
      return lockPath
    } catch {
      // Held by someone else, unless they crashed and left it behind.
    }
    let stamp: number | null = null
    try {
      stamp = Number(readFileSync(ownerPath, 'utf8').split(/\s+/)[1])
    } catch {
      stamp = null
    }
    if (stamp && nowSeconds() - stamp > STALE_LOCK_SECONDS) {
      rmSync(lockPath, { recursive: true, force: true })
      continue
    }
    if (Date.now() > deadline) throw new Error(`timed out waiting for ${lockPath}`)
    await pause(50)
  }
}

let sequence = 0
const backupTime = (date: Date) => date.toISOString().slice(0, 19).replace(/[-:]/g, '') + 'Z'

function backupCurrent(file: string) {
  if (!existsSync(file)) return
  const now = new Date()
  const folder = join(dirname(file), BACKUPS)
  mkdirSync(folder, { recursive: true })
  const revision = (JSON.parse(readFileSync(file, 'utf8')) as Doc).revision
  copyFileSync(file, join(folder, `orion-r${revision}-${backupTime(now)}.json`), constants.COPYFILE_EXCL)

  const hourCutoff = backupTime(new Date(now.getTime() - DAY_MS))
  const dayCutoff = backupTime(new Date(now.getTime() - (DAILY_DAYS - 1) * DAY_MS)).slice(0, 8)
  const current = backupTime(now)
  const keptDays = new Set<string>()
  const backups = readdirSync(folder, { withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => ({ name: entry.name, time: entry.name.match(/^orion-r\d+-(\d{8}T\d{6}Z)\.json$/)?.[1] }))
    .filter((entry): entry is { name: string; time: string } => entry.time !== undefined)
    .sort((a, b) => b.time.localeCompare(a.time) || b.name.localeCompare(a.name))
  for (const { name, time } of backups) {
    const day = time.slice(0, 8)
    const isInDailyRange = day >= dayCutoff && day <= current.slice(0, 8) && time <= current
    if (time >= hourCutoff && time <= current) {
      if (isInDailyRange) keptDays.add(day)
    } else if (isInDailyRange && !keptDays.has(day)) {
      keptDays.add(day)
    } else {
      unlinkSync(join(folder, name))
    }
  }
}

function atomicWrite(file: string, contents: string) {
  sequence += 1
  const temporary = `${file}.tmp.${process.pid}.${sequence}`
  writeFileSync(temporary, contents)
  // Backups are best-effort: a failed backup never blocks the write itself.
  try {
    backupCurrent(file)
  } catch (error) {
    console.warn(`[orion] backup skipped: ${String(error)}`)
  }
  try {
    renameSync(temporary, file)
  } catch (error) {
    rmSync(temporary, { force: true })
    throw error
  }
}

async function body(req: IncomingMessage) {
  const chunks: Buffer[] = []
  for await (const chunk of req) chunks.push(chunk as Buffer)
  return JSON.parse(Buffer.concat(chunks).toString('utf8'))
}

type Put = { baseRevision: number | null; nodes: unknown[]; links: unknown[] }

/** Writes the canvas when nobody else has changed it since `baseRevision`. */
async function put(dir: string, change: Put): Promise<{ status: number; revision: number | null }> {
  mkdirSync(dir, { recursive: true })
  const lockPath = await acquire(dir)
  try {
    const current = read(dir)
    const revision = current ? current.revision : null
    if (change.baseRevision !== revision) return { status: 409, revision }
    const next: Doc = {
      ...(current ?? { version: 1, settings: { githubOwner: 'flipbook-labs' } }),
      revision: current ? current.revision + 1 : 0,
      nodes: change.nodes,
      links: change.links,
    }
    atomicWrite(join(dir, FILE), JSON.stringify(next, null, 2))
    return { status: 200, revision: next.revision }
  } finally {
    rmSync(lockPath, { recursive: true, force: true })
  }
}

export function orionStore(): Plugin {
  const root = dataDir()
  return {
    name: 'orion-store',
    apply: 'serve',
    configureServer(server) {
      mkdirSync(root, { recursive: true })
      let list = getWorkspaces(root)
      let active = list.active
      knownWorkspace(list, active)
      let dir = getWorkspaceDir(root, active)
      mkdirSync(dir, { recursive: true })
      let status: SyncStatus = { state: 'idle' }
      let running = false
      let lastFinished = 0
      let generation = 0
      const binary = process.env.ORION_BIN || fileURLToPath(new URL('../../cli/build/orion', import.meta.url))
      const publish = (next: SyncStatus) => {
        status = next
        server.ws.send({ type: 'custom', event: 'orion:sync', data: status })
      }
      const sync = async (force = false): Promise<SyncStatus> => {
        if (running || (!force && lastFinished && Date.now() - lastFinished < SYNC_THROTTLE_MS)) return status
        const started = generation
        running = true
        publish({ ...status, state: 'running', message: undefined })
        try {
          await execFileAsync(binary, ['sync', '--json'], { env: { ...process.env, ORION_DATA_DIR: root, ORION_WORKSPACE: active } })
          if (started === generation) publish({ state: 'idle', lastRun: new Date().toISOString() })
        } catch (error) {
          const failure = error as Error & { code?: string; stderr?: string }
          const lastRun = new Date().toISOString()
          if (started === generation) {
            if (failure.code === 'ENOENT') publish({ state: 'unavailable', lastRun, message: 'Build the CLI: cd cli && lute run build' })
            else publish({ state: 'error', lastRun, message: failure.stderr?.trim().split(/\r?\n/).at(-1) || failure.message })
          }
        } finally {
          if (started === generation) lastFinished = Date.now()
          running = false
          if (started !== generation) void sync(true)
        }
        return status
      }
      const reply = (res: import('node:http').ServerResponse, code: number, value: unknown) => {
        res.statusCode = code
        res.setHeader('content-type', 'application/json')
        res.end(JSON.stringify(value))
      }
      let timer: ReturnType<typeof setTimeout> | undefined
      const watchFolder = (folder: string) =>
        watch(folder, (_event, name) => {
          if (name !== FILE || folder !== dir) return
          clearTimeout(timer)
          timer = setTimeout(() => {
            try {
              const doc = read(dir)
              if (doc) server.ws.send({ type: 'custom', event: CHANGED_EVENT, data: { revision: doc.revision } })
            } catch {
              // Caught mid-write; the next event carries the finished file.
            }
          }, 60)
        })
      let watcher = watchFolder(dir)
      const switchTo = (name: string) => {
        if (name === active) return
        const nextDir = getWorkspaceDir(root, name)
        mkdirSync(nextDir, { recursive: true })
        const nextWatcher = watchFolder(nextDir)
        watcher.close()
        watcher = nextWatcher
        active = name
        dir = nextDir
        generation += 1
        lastFinished = 0
        status = { state: 'idle' }
        server.ws.send({ type: 'custom', event: 'orion:workspace', data: { active } })
        void sync(true)
      }
      const manifestWatcher = watch(root, (_event, name) => {
        if (name !== WORKSPACES_FILE) return
        try {
          list = getWorkspaces(root)
          const name = list.active
          knownWorkspace(list, name)
          switchTo(name)
        } catch {
          // A concurrent writer may still be finishing the manifest.
        }
      })
      server.middlewares.use(WORKSPACES_API, async (req, res, next) => {
        const pathname = new URL(req.url ?? '', 'http://localhost').pathname
        try {
          if (pathname === '/active' && req.method === 'POST') {
            const { name } = (await body(req)) as { name?: unknown }
            list = getWorkspaces(root)
            knownWorkspace(list, name)
            list.active = name
            writeWorkspaces(root, list)
            switchTo(name)
            return reply(res, 200, list)
          }
          if (pathname === '/' && req.method === 'GET') return reply(res, 200, { ...getWorkspaces(root), active })
          if (pathname === '/' && req.method === 'POST') {
            const { name, label } = (await body(req)) as { name?: unknown; label?: unknown }
            if (!isValidWorkspace(name)) throw new Error(`invalid workspace name: ${String(name)}`)
            if (label !== undefined && (typeof label !== 'string' || !label.trim())) throw new Error('label must be nonempty')
            list = getWorkspaces(root)
            if (list.workspaces.some((entry) => entry.name === name)) throw new Error(`workspace already exists: ${name}`)
            const folder = getWorkspaceDir(root, name)
            if (existsSync(folder)) throw new Error(`workspace folder already exists: ${folder}`)
            mkdirSync(folder, { recursive: true })
            await put(folder, { baseRevision: null, nodes: [], links: [] })
            list.workspaces.push({ name, label: typeof label === 'string' ? label : name })
            writeWorkspaces(root, list)
            return reply(res, 201, { ...list, active })
          }
          next()
        } catch (error) {
          reply(res, 400, { error: String(error) })
        }
      })
      server.middlewares.use(SYNC_API, async (req, res) => {
        if (req.method === 'GET') return reply(res, 200, status)
        if (req.method === 'POST') return reply(res, 200, await sync(new URL(req.url ?? '', 'http://localhost').searchParams.get('force') === '1'))
        reply(res, 405, { error: 'method not allowed' })
      })
      server.middlewares.use(API, async (req, res) => {
        try {
          if (req.method === 'GET') {
            const doc = read(dir)
            return doc ? reply(res, 200, doc) : reply(res, 404, { path: join(dir, FILE), workspace: active })
          }
          if (req.method === 'PUT') {
            if (req.headers['x-orion-workspace'] && req.headers['x-orion-workspace'] !== active)
              return reply(res, 409, { error: 'workspace changed' })
            const result = await put(dir, (await body(req)) as Put)
            return reply(res, result.status, { revision: result.revision })
          }
          reply(res, 405, { error: 'method not allowed' })
        } catch (error) {
          reply(res, 500, { error: String(error) })
        }
      })

      const startup = setTimeout(() => void sync(), 5000)
      const interval = setInterval(() => void sync(), SYNC_INTERVAL_MS)
      server.httpServer?.on('close', () => {
        clearTimeout(startup)
        clearInterval(interval)
        clearTimeout(timer)
        watcher.close()
        manifestWatcher.close()
      })
    },
  }
}
