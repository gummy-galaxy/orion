import type { GithubState, ItemKind, TaskData } from './model'

/**
 * A card's sources are typed references to the things it stands for. Tracking sources say what the work is,
 * implementation sources stack on top of them and drive live status, and context sources are links only.
 * Mirrors `cli/src/refs.luau`.
 */
export type SourceKind = 'github-pr' | 'github-issue' | 'github-release' | 'jira' | 'slack' | 'hop' | 'url'
export type SourceRole = 'tracking' | 'implementation' | 'context'

export type JiraState = {
  status: string
  statusCategory: 'new' | 'indeterminate' | 'done'
  type: string
  epicKey?: string
  epicSummary?: string
  updatedAt?: string
}
export type HopState = { lastActiveAt: string; sessions: string[] }
export type ReleaseState = { name?: string; url?: string; publishedAt?: string; draft?: boolean; prerelease?: boolean; checkedAt?: string }

type Common = { via?: string }
export type PullSource = Common & { kind: 'github-pr'; repo: string; number?: number; host?: string; branch?: string; state?: GithubState }
export type IssueSource = Common & { kind: 'github-issue'; repo: string; number: number; host?: string; state?: { title?: string; url?: string } }
export type ReleaseSource = Common & { kind: 'github-release'; repo: string; tag: string; host?: string; state?: ReleaseState }
export type JiraSource = Common & { kind: 'jira'; key: string; url?: string; state?: JiraState }
export type HopSource = Common & { kind: 'hop'; repo: string; branch: string; host?: string; state?: HopState }
export type LinkSource = Common & { kind: 'slack' | 'url'; url: string; label?: string }
export type Source = PullSource | IssueSource | ReleaseSource | JiraSource | HopSource | LinkSource

export const SOURCE_KINDS: SourceKind[] = ['github-pr', 'github-issue', 'github-release', 'jira', 'slack', 'hop', 'url']

const ROLE: Record<SourceKind, SourceRole> = {
  jira: 'tracking',
  'github-issue': 'tracking',
  'github-pr': 'implementation',
  hop: 'implementation',
  'github-release': 'context',
  slack: 'context',
  url: 'context',
}
const ROLE_ORDER: Record<SourceRole, number> = { tracking: 1, implementation: 2, context: 3 }

export const roleOf = (source: Source): SourceRole => ROLE[source.kind] ?? 'context'

export const sourcesOf = (data: TaskData): Source[] => data.sources ?? []

/** Tracking sources first, then implementation in the order they stacked, then context. */
export function ordered(data: TaskData): Source[] {
  return sourcesOf(data)
    .map((source, index) => ({ source, index }))
    .sort((a, b) => ROLE_ORDER[roleOf(a.source)] - ROLE_ORDER[roleOf(b.source)] || a.index - b.index)
    .map(({ source }) => source)
}

/** Pull requests that exist, as opposed to expected ones. */
export const pulls = (data: TaskData): PullSource[] =>
  sourcesOf(data).filter((s): s is PullSource => s.kind === 'github-pr' && typeof s.number === 'number')

/** The pull request whose state the card shows: the topmost open one, else the topmost. */
export function driver(data: TaskData): PullSource | undefined {
  const list = pulls(data)
  return [...list].reverse().find((s) => s.state?.state === 'OPEN') ?? list[list.length - 1]
}

export function itemKindFor(data: TaskData): ItemKind {
  if (data.itemKind === 'note' || data.itemKind === 'gate') return data.itemKind
  const list = sourcesOf(data)
  if (list.some((s) => s.kind === 'github-pr' && typeof s.number === 'number')) return 'pr'
  if (list.some((s) => s.kind === 'github-pr' || s.kind === 'github-issue')) return 'placeholder'
  return 'step'
}

/** Identity, ignoring the snapshot and provenance. Expected pull requests share one identity per repository. */
export function identity(source: Source): string {
  switch (source.kind) {
    case 'github-pr':
    case 'github-issue':
      return `${source.kind}:${(source.host ?? 'github.com').toLowerCase()}/${source.repo.toLowerCase()}#${source.number ?? ''}`
    case 'github-release':
      return `${source.kind}:${(source.host ?? 'github.com').toLowerCase()}/${source.repo.toLowerCase()}@${source.tag}`
    case 'jira':
      return `jira:${source.key.toUpperCase()}`
    case 'hop':
      return `hop:${source.repo.toLowerCase()}:${source.branch}`
    default:
      return `${source.kind}:${source.url}`
  }
}

function hostname(url: string): string | undefined {
  try {
    return new URL(url).hostname
  } catch {
    return undefined
  }
}

export function sourceTag(source: Source): string {
  switch (source.kind) {
    case 'github-pr':
    case 'github-issue':
      return typeof source.number === 'number' ? `${source.repo}#${source.number}` : source.repo
    case 'github-release':
      return `${source.repo}@${source.tag}`
    case 'jira':
      return source.key
    case 'hop':
      return source.repo
    case 'slack':
      return source.label ?? 'Slack'
    default:
      return source.label ?? hostname(source.url) ?? source.url
  }
}

/** The card's tag: its tracking source when it has one, else what implements it, else context. */
export function taskTag(data: TaskData): string {
  const first = ordered(data)[0]
  return first ? sourceTag(first) : data.itemKind === 'gate' ? 'gate' : 'step'
}

const fullRepo = (repo: string, owner: string) => (repo.includes('/') ? repo : `${owner}/${repo}`)

export function sourceUrl(source: Source, owner: string): string | null {
  const host = 'host' in source && source.host ? source.host : 'github.com'
  switch (source.kind) {
    case 'github-pr':
      return source.state?.url ?? (typeof source.number === 'number' ? `https://${host}/${fullRepo(source.repo, owner)}/pull/${source.number}` : null)
    case 'github-issue':
      return source.state?.url ?? `https://${host}/${fullRepo(source.repo, owner)}/issues/${source.number}`
    case 'github-release':
      return source.state?.url ?? `https://${host}/${fullRepo(source.repo, owner)}/releases/tag/${encodeURIComponent(source.tag)}`
    case 'jira':
      return source.url ?? null
    case 'hop':
      return null
    default:
      return source.url
  }
}

/** The first source, in precedence order, that has somewhere to open. */
export function primaryLink(data: TaskData, owner: string): { url: string; tag: string } | null {
  for (const source of ordered(data)) {
    const url = sourceUrl(source, owner)
    if (url) return { url, tag: sourceTag(source) }
  }
  return null
}

const withKind = (data: TaskData, sources: Source[]): Partial<TaskData> => {
  const next = { ...data, sources: sources.length ? sources : undefined }
  return { sources: next.sources, itemKind: itemKindFor(next) }
}

/**
 * The patch that adds a source, or refreshes the identity fields of one already there. A pull request with a
 * number fills in an expected pull request for the same repository.
 */
export function attachSource(data: TaskData, source: Source): Partial<TaskData> {
  const list = sourcesOf(data)
  let index = list.findIndex((s) => identity(s) === identity(source))
  if (index < 0 && source.kind === 'github-pr' && typeof source.number === 'number') {
    const expected = identity({ kind: 'github-pr', repo: source.repo, host: source.host })
    index = list.findIndex((s) => identity(s) === expected)
  }
  if (index < 0) return withKind(data, [...list, source])
  const { state: _state, ...fields } = source as Source & { state?: unknown }
  return withKind(
    data,
    list.map((s, i) => (i === index ? ({ ...s, ...fields } as Source) : s)),
  )
}

export function detachSource(data: TaskData, source: Source): Partial<TaskData> {
  const id = identity(source)
  return withKind(
    data,
    sourcesOf(data).filter((s) => identity(s) !== id),
  )
}

// ---- Parsing what someone types into the inspector ----

const REPO = /^[\w.-]+$/
const OWNER_REPO = /^([\w.-]+)\/([\w.-]+)$/
const JIRA_KEY = /^[A-Za-z][A-Za-z0-9]*-\d+$/

const shortRepo = (owner: string, name: string, defaultOwner: string) =>
  owner.toLowerCase() === defaultOwner.toLowerCase() ? name : `${owner}/${name}`

function repoPart(text: string, defaultOwner: string): string {
  const m = OWNER_REPO.exec(text)
  if (m) return shortRepo(m[1], m[2], defaultOwner)
  if (!REPO.test(text)) throw new Error(`Invalid repository ${text}`)
  return text
}

function fromUrl(text: string, defaultOwner: string): Source {
  let url: URL
  try {
    url = new URL(text)
  } catch {
    throw new Error(`${text} isn't a URL`)
  }
  if (url.protocol !== 'https:' || url.username || url.password) throw new Error('Source URLs need HTTPS without credentials')
  const host = url.hostname.toLowerCase()
  const hostField = host === 'github.com' ? undefined : host
  const path = url.pathname
  let m = /^\/([^/]+)\/([^/]+)\/pull\/(\d+)/.exec(path)
  if (m) return { kind: 'github-pr', repo: shortRepo(m[1], m[2], defaultOwner), number: Number(m[3]), host: hostField }
  m = /^\/([^/]+)\/([^/]+)\/issues\/(\d+)/.exec(path)
  if (m) return { kind: 'github-issue', repo: shortRepo(m[1], m[2], defaultOwner), number: Number(m[3]), host: hostField }
  m = /^\/([^/]+)\/([^/]+)\/releases\/tag\/(.+)$/.exec(path)
  if (m) return { kind: 'github-release', repo: shortRepo(m[1], m[2], defaultOwner), tag: decodeURIComponent(m[3]), host: hostField }
  m = /\/browse\/([A-Za-z][A-Za-z0-9]*-\d+)$/.exec(path)
  if (m) return { kind: 'jira', key: m[1].toUpperCase(), url: text }
  if (host === 'slack.com' || host.endsWith('.slack.com')) return { kind: 'slack', url: text }
  return { kind: 'url', url: text }
}

const clean = <T extends object>(value: T): T => Object.fromEntries(Object.entries(value).filter(([, v]) => v !== undefined)) as T

/**
 * Reads a source from a URL, or from short forms: `repo#123` for a pull request, `repo` for an expected one,
 * `repo@tag` for a release, `KEY-123` for Jira, and `repo:branch` for hop. Pass `kind` to pick between forms
 * that look alike, such as a pull request and an issue.
 */
export function parseSource(text: string, defaultOwner: string, kind?: SourceKind): Source {
  const value = text.trim()
  if (!value) throw new Error('Enter a URL or a reference')
  if (/^https?:\/\//.test(value)) {
    if (kind === 'slack' || kind === 'url') return { kind, url: value }
    const source = fromUrl(value, defaultOwner)
    if (kind && source.kind !== kind) throw new Error(`${value} isn't a ${kind} URL`)
    return clean(source)
  }
  if (kind === 'slack' || kind === 'url') throw new Error(`${kind === 'slack' ? 'Slack' : 'Link'} sources need a URL`)
  if ((!kind || kind === 'jira') && JIRA_KEY.test(value) && !value.includes('#')) return { kind: 'jira', key: value.toUpperCase() }
  if (kind === 'jira') throw new Error('Jira sources look like KEY-123')
  const release = /^([^@#:]+)@(.+)$/.exec(value)
  if ((!kind && release) || kind === 'github-release') {
    if (!release) throw new Error('Releases look like repo@tag')
    return { kind: 'github-release', repo: repoPart(release[1], defaultOwner), tag: release[2] }
  }
  const hop = /^([^:#]+):(.+)$/.exec(value)
  if ((!kind && hop) || kind === 'hop') {
    if (!hop) throw new Error('Hop sources look like repo:branch')
    return { kind: 'hop', repo: repoPart(hop[1], defaultOwner), branch: hop[2] }
  }
  const numbered = /^(.+)#(\d+)$/.exec(value)
  if (kind === 'github-issue') {
    if (!numbered) throw new Error('Issues need a number, as repo#123')
    return { kind, repo: repoPart(numbered[1], defaultOwner), number: Number(numbered[2]) }
  }
  if (numbered) return { kind: 'github-pr', repo: repoPart(numbered[1], defaultOwner), number: Number(numbered[2]) }
  return { kind: 'github-pr', repo: repoPart(value, defaultOwner) }
}

// ---- Cards saved before typed sources ----

type Legacy = {
  repo?: string
  pr?: number
  host?: string
  issue?: number
  branch?: string
  github?: GithubState
  jira?: JiraState & { key: string; url?: string }
  activity?: HopState
  sources?: (string | Source)[]
}
const LEGACY = ['repo', 'pr', 'host', 'issue', 'branch', 'github', 'jira', 'activity'] as const

const family = (kind: string) => (kind === 'jira' ? 'jira' : kind === 'hop' ? 'hop' : 'github')

/** Moves the fields cards used before typed sources into `sources`, as the CLI does when it reads a file. */
export function migrateTask(data: TaskData): TaskData {
  const old = data as Omit<TaskData, 'sources'> & Legacy
  const raw = old.sources ?? []
  if (!LEGACY.some((key) => old[key] !== undefined) && !raw.some((entry) => typeof entry === 'string')) return data
  const list: Source[] = raw.filter((entry): entry is Source => typeof entry === 'object' && !!entry?.kind)
  const feeds = raw.filter((entry): entry is string => typeof entry === 'string')
  const { repo, host, branch, pr, issue, jira, activity, github } = old
  if (jira?.key) {
    const { key, url, ...state } = jira
    list.push(clean({ kind: 'jira', key, url, state: state as JiraState }))
  }
  if (repo && typeof issue === 'number') list.push(clean({ kind: 'github-issue', repo, number: issue, host }))
  if (repo && typeof pr === 'number') list.push(clean({ kind: 'github-pr', repo, number: pr, host, branch, state: github }))
  const hop = !!repo && !!branch && (activity !== undefined || (typeof pr !== 'number' && typeof issue !== 'number'))
  if (hop) list.push(clean({ kind: 'hop', repo: repo!, branch: branch!, host, state: activity }))
  if (repo && typeof pr !== 'number' && typeof issue !== 'number' && !hop) list.push(clean({ kind: 'github-pr', repo, host }))
  for (const id of feeds) {
    const want = id.startsWith('jira') ? 'jira' : id.startsWith('hop') ? 'hop' : 'github'
    for (const [i, source] of list.entries()) if (!source.via && family(source.kind) === want) list[i] = { ...source, via: id }
  }
  const next = { ...old }
  for (const key of LEGACY) delete next[key]
  if (list.length) next.sources = list
  else delete next.sources
  const migrated = next as TaskData
  migrated.itemKind = itemKindFor(migrated)
  return migrated
}

// ---- Badges ----

/** How a source shows at the bottom right of a tile: bundled icons for known services, a favicon for links. */
export type Badge = { icon: 'github' | 'jira' | 'slack' | 'hop' | 'url' | 'orion'; domain: string; label: string; href?: string }

export const SERVICE_NAME: Record<Badge['icon'], string | null> = {
  github: 'GitHub',
  jira: 'Jira',
  slack: 'Slack',
  hop: 'hop',
  orion: 'Orion',
  url: null,
}

export function badgeOf(source: Source, owner: string): Badge {
  const href = sourceUrl(source, owner) ?? undefined
  const label = sourceTag(source)
  switch (source.kind) {
    case 'github-pr':
    case 'github-issue':
    case 'github-release':
      return { icon: 'github', domain: source.host ?? 'github.com', label, href }
    case 'jira':
      return { icon: 'jira', domain: (source.url && hostname(source.url)) || 'jira', label, href }
    case 'slack':
      return { icon: 'slack', domain: 'slack.com', label, href }
    case 'hop':
      return { icon: 'hop', domain: 'hop', label, href }
    default: {
      const domain = hostname(source.url) ?? source.url
      return { icon: GITHUB_HOST.test(domain) ? 'github' : 'url', domain, label, href }
    }
  }
}

const GITHUB_HOST = /^(?:www\.)?github\.com$/i

/** Badges group by service; links group by site. */
export const badgeGroup = (badge: Badge) => (badge.icon === 'url' ? `url:${badge.domain}` : badge.icon)
