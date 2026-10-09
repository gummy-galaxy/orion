import { createHash } from 'node:crypto'
import { execFile } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { promisify } from 'node:util'
import type { Plugin } from 'vite'

/**
 * Finds art for a card's GitHub source: the first image or video in a pull request's description, else the social
 * preview GitHub draws for it. Private repositories all get the same generic preview, which counts as nothing.
 * Results are cached on disk, and requests to GitHub go out one at a time because the preview service rate-limits.
 */

const API = '/api/media'
const CACHE = join(tmpdir(), 'orion-media')
/** The preview GitHub serves for anything it won't render, such as a private repository. */
const GENERIC_PREVIEW = '0fa6c94822b6'
const PATH = /^[\w.-]+\/[\w.-]+(?:\/(?:pull|issues)\/\d+)?$/
const BODY_MEDIA = [
  /!\[[^\]]*\]\((https:\/\/[^)\s]+)\)/,
  /<(?:img|video|source)[^>]*\ssrc="(https:\/\/[^"]+)"/,
  /^\s*(https:\/\/github\.com\/user-attachments\/assets\/[\w-]+)\s*$/m,
]
const execFileAsync = promisify(execFile)

type Found = { file: string; type: string; from: 'body' | 'preview' } | null

let token: Promise<string | null> | null = null
const ghToken = () =>
  (token ??= execFileAsync('gh', ['auth', 'token'])
    .then((r) => r.stdout.trim() || null)
    .catch(() => null))

let chain: Promise<unknown> = Promise.resolve()

function oneAtATime<T>(work: () => Promise<T>): Promise<T> {
  const run = chain.then(work, work)

  chain = run.catch(() => undefined)

  return run
}

const pause = (ms: number) => new Promise((done) => setTimeout(done, ms))

async function fetchBytes(url: string, auth: boolean): Promise<{ bytes: Buffer; type: string } | null> {
  for (let attempt = 0; attempt < 4; attempt++) {
    const headers: Record<string, string> = { 'user-agent': 'orion-dev' }
    const t = auth ? await ghToken() : null

    if (t) headers.authorization = `token ${t}`

    const res = await fetch(url, { headers, redirect: 'follow' })

    if (res.status === 429) {
      await pause(1500 * 2 ** attempt)
      continue
    }

    if (!res.ok) return null

    return { bytes: Buffer.from(await res.arrayBuffer()), type: res.headers.get('content-type') ?? 'application/octet-stream' }
  }

  return null
}

async function bodyMedia(path: string): Promise<{ bytes: Buffer; type: string } | null> {
  const [owner, repo, kind, number] = path.split('/')

  if (!number) return null

  const endpoint = `repos/${owner}/${repo}/${kind === 'pull' ? 'pulls' : 'issues'}/${number}`
  const body = await execFileAsync('gh', ['api', endpoint, '--jq', '.body'])
    .then((r) => r.stdout)
    .catch(() => '')

  for (const pattern of BODY_MEDIA) {
    const url = pattern.exec(body)?.[1]

    if (!url) continue

    const got = await fetchBytes(url, /^https:\/\/(github\.com|[\w.-]*githubusercontent\.com)\//.test(url))

    if (got && /^(image|video)\//.test(got.type)) return got
  }

  return null
}

async function preview(path: string) {
  const got = await fetchBytes(`https://opengraph.githubassets.com/orion/${path}`, false)

  if (!got || !got.type.startsWith('image/')) return null

  return createHash('sha1').update(got.bytes).digest('hex').startsWith(GENERIC_PREVIEW) ? null : got
}

const pending = new Map<string, Promise<Found>>()

function find(path: string): Promise<Found> {
  const key = createHash('sha1').update(path).digest('hex').slice(0, 16)
  const meta = join(CACHE, `${key}.json`)

  if (existsSync(meta)) return Promise.resolve(JSON.parse(readFileSync(meta, 'utf8')) as Found)

  const known = pending.get(key)

  if (known) return known

  const work = oneAtATime(async (): Promise<Found> => {
    const fromBody = await bodyMedia(path)
    const got = fromBody ?? (await preview(path))
    const found: Found = got ? { file: `${key}.bin`, type: got.type, from: fromBody ? 'body' : 'preview' } : null

    mkdirSync(CACHE, { recursive: true })

    if (got) writeFileSync(join(CACHE, `${key}.bin`), got.bytes)

    writeFileSync(meta, JSON.stringify(found))

    return found
  }).finally(() => pending.delete(key))

  pending.set(key, work)

  return work
}

export function orionMedia(): Plugin {
  return {
    name: 'orion-media',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use(API, async (req, res) => {
        const url = new URL(req.url ?? '', 'http://localhost')
        const file = /^\/file\/([0-9a-f]{16}\.bin)$/.exec(url.pathname)?.[1]

        if (file) {
          const type = url.searchParams.get('type') ?? 'application/octet-stream'

          res.setHeader('content-type', type)
          res.setHeader('cache-control', 'max-age=86400')

          return res.end(readFileSync(join(CACHE, file)))
        }

        const path = url.searchParams.get('path') ?? ''

        res.setHeader('content-type', 'application/json')

        if (!PATH.test(path)) {
          res.statusCode = 400

          return res.end('{}')
        }

        try {
          const found = await find(path)

          res.end(
            JSON.stringify(
              found
                ? {
                    src: `${API}/file/${found.file}?type=${encodeURIComponent(found.type)}`,
                    video: found.type.startsWith('video/'),
                    from: found.from,
                  }
                : null,
            ),
          )
        } catch (error) {
          res.statusCode = 500
          res.end(JSON.stringify({ error: String(error) }))
        }
      })
    },
  }
}
