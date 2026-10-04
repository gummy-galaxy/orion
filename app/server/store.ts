import { existsSync, mkdirSync, readFileSync, renameSync, rmSync, watch, writeFileSync } from 'node:fs'
import type { IncomingMessage } from 'node:http'
import { homedir } from 'node:os'
import { join, resolve } from 'node:path'
import type { Plugin } from 'vite'

/**
 * Serves orion.json to the app during development. The CLI takes the same
 * mkdir lock and writes the same way, so either side can edit while the other
 * is open, and every change is announced to open pages.
 */

const FILE = 'orion.json'
const LOCK = 'orion.lock'
const LOCK_TIMEOUT_MS = 5000
const STALE_LOCK_SECONDS = 30
const API = '/api/orion'
export const CHANGED_EVENT = 'orion:changed'

type Doc = { version: number; revision: number; settings: { githubOwner: string }; nodes: unknown[]; links: unknown[] }

export function dataDir() {
  const configured = process.env.ORION_DATA_DIR
  return configured ? resolve(configured) : join(homedir(), 'Library', 'Application Support', 'Orion')
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
function atomicWrite(file: string, contents: string) {
  sequence += 1
  const temporary = `${file}.tmp.${process.pid}.${sequence}`
  writeFileSync(temporary, contents)
  renameSync(temporary, file)
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
  const dir = dataDir()
  return {
    name: 'orion-store',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use(API, async (req, res) => {
        const reply = (status: number, value: unknown) => {
          res.statusCode = status
          res.setHeader('content-type', 'application/json')
          res.end(JSON.stringify(value))
        }
        try {
          if (req.method === 'GET') {
            const doc = read(dir)
            return doc ? reply(200, doc) : reply(404, { path: join(dir, FILE) })
          }
          if (req.method === 'PUT') {
            const result = await put(dir, (await body(req)) as Put)
            return reply(result.status, { revision: result.revision })
          }
          reply(405, { error: 'method not allowed' })
        } catch (error) {
          reply(500, { error: String(error) })
        }
      })

      // Watch the folder: atomic writes replace the file, which ends a watch on the file itself.
      mkdirSync(dir, { recursive: true })
      let timer: ReturnType<typeof setTimeout> | undefined
      const watcher = watch(dir, (_event, name) => {
        if (name !== FILE) return
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
      server.httpServer?.on('close', () => watcher.close())
    },
  }
}
