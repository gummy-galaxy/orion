import type { Derived, GroupStats } from '../../derive'
import type { AppNode, Link, TaskData, ViewStatus } from '../../model'
import type { Operation } from '../../operations'
import type { Remote, Saved } from '../../persist'

/** What a story's stand-in server received, newest last, for the story to show. */
export type SentOperations = { revision: number; operations: Operation[] }

let sent: SentOperations[] = []
const listeners = new Set<() => void>()

/** The operations the stand-in received since the story loaded, for `useSyncExternalStore`. */
export const sentOperations = {
  get: () => sent,
  subscribe: (listener: () => void) => {
    listeners.add(listener)

    return () => listeners.delete(listener)
  },
}

/**
 * Spike #102: a small stand-in for `orion serve` that applies the operations the canvas sends and derives status the
 * way the server does for the common cases, so an edit in the table round-trips: the app sends it, the stand-in
 * applies it, and the reload brings back the new derived status. Group, ungroup, and image operations aren't handled.
 */
export function fakeServe(seed: Saved) {
  let doc: Saved = structuredClone(seed)
  let revision = 1

  sent = []
  const originalFetch = globalThis.fetch
  const OriginalWebSocket = globalThis.WebSocket
  const sockets = new Set<FakeSocket>()

  // The server pushes derived facts with each change over `/api/events`, which is how a card's status catches up.
  class FakeSocket {
    onopen: (() => void) | null = null
    onmessage: ((message: { data: string }) => void) | null = null
    onclose: (() => void) | null = null
    onerror: (() => void) | null = null

    constructor() {
      sockets.add(this)
      setTimeout(() => this.onopen?.())
    }

    send() {}

    close() {
      sockets.delete(this)
      this.onclose?.()
    }
  }

  globalThis.WebSocket = function (url: string | URL) {
    return String(url).endsWith('/api/events') ? new FakeSocket() : new OriginalWebSocket(url)
  } as unknown as typeof WebSocket

  globalThis.fetch = async (input, init) => {
    const path = String(input)
    const method = init?.method ?? 'GET'

    if (path === '/api/orion' && method === 'GET') {
      const remote: Remote = { ...structuredClone(doc), revision, settings: {}, derived: derive(doc) }

      return Response.json(remote)
    }

    if (path === '/api/operations' && method === 'POST') {
      const { operations } = JSON.parse(String(init?.body)) as { operations: Operation[] }

      doc = operations.reduce(applyOperation, doc)
      revision += 1
      sent = [...sent, { revision, operations }]

      for (const listener of listeners) listener()

      const message = JSON.stringify({ event: 'orion:changed', data: { revision, derived: derive(doc) } })

      setTimeout(() => sockets.forEach((socket) => socket.onmessage?.({ data: message })), 50)

      return Response.json({ revision })
    }

    return originalFetch(input, init)
  }

  return () => {
    globalThis.fetch = originalFetch
    globalThis.WebSocket = OriginalWebSocket
    sockets.forEach((socket) => socket.close())
  }
}

function applyOperation(doc: Saved, operation: Operation): Saved {
  const id = operation.id as string
  const editNode = (edit: (node: AppNode) => AppNode) => ({ ...doc, nodes: doc.nodes.map((node) => (node.id === id ? edit(node) : node)) })

  switch (operation.op) {
    case 'setData':
      return editNode((node) => ({ ...node, data: operation.data }) as AppNode)
    case 'place':
      return editNode((node) => ({ ...node, position: { x: operation.x as number, y: operation.y as number } }))
    case 'resize':
      return editNode((node) => ({ ...node, width: operation.width as number | undefined, height: operation.height as number | undefined }))
    case 'move':
      return editNode((node) => ({ ...node, parentId: operation.group as string | undefined }))

    case 'link': {
      const rest = doc.links.filter((link) => !(link.from === operation.from && link.to === operation.to))
      const link = { id: `${operation.from}>${operation.to}`, from: operation.from, to: operation.to, kind: operation.kind } as Link

      return { ...doc, links: [...rest, link] }
    }

    case 'unlink':
      return { ...doc, links: doc.links.filter((link) => !(link.from === operation.from && link.to === operation.to)) }
    case 'remove':
    case 'removeGroup':
      return { ...doc, nodes: doc.nodes.filter((node) => node.id !== id), links: doc.links.filter((link) => link.from !== id && link.to !== id) }
    case 'addCard':
    case 'addNote':

    case 'addGroup': {
      const type = operation.op === 'addGroup' ? 'cluster' : 'task'
      const node = { id, type, position: { x: operation.x, y: operation.y }, parentId: operation.group, data: operation.data } as AppNode

      return { ...doc, nodes: [...doc.nodes, node] }
    }

    default:
      return doc
  }
}

/** Recorded status, except that open work waiting on open work is blocked, and a gate is done once all it waits on is. */
function derive(doc: Saved): Derived {
  const tasks = new Map(doc.nodes.filter((node) => node.type === 'task').map((node) => [node.id, node.data as TaskData]))
  const waitsOn = new Map<string, string[]>()

  for (const link of doc.links) if (link.kind === 'blocks') waitsOn.set(link.to, [...(waitsOn.get(link.to) ?? []), link.from])

  const status: Record<string, ViewStatus> = {}

  const statusOf = (id: string, seen = new Set<string>()): ViewStatus | undefined => {
    const data = tasks.get(id)

    if (!data || data.itemKind === 'component' || data.itemKind === 'note') return undefined

    if (status[id]) return status[id]

    if (seen.has(id)) return 'ready'

    seen.add(id)
    const open = (waitsOn.get(id) ?? []).some((other) => {
      const otherStatus = statusOf(other, seen)

      return otherStatus !== undefined && otherStatus !== 'done'
    })
    let result: ViewStatus

    if (data.itemKind === 'gate') result = open ? 'blocked' : 'done'
    else if (data.status !== 'todo') result = data.status
    else result = open ? 'blocked' : 'ready'

    status[id] = result

    return result
  }

  for (const id of tasks.keys()) statusOf(id)

  const groups: Record<string, GroupStats> = {}

  for (const node of doc.nodes) {
    if (node.type !== 'cluster') continue

    const inside = doc.nodes.filter((child) => child.parentId === node.id && status[child.id])

    groups[node.id] = {
      total: inside.length,
      done: inside.filter((child) => status[child.id] === 'done').length,
      ready: inside.filter((child) => status[child.id] === 'ready').length,
      blocked: inside.filter((child) => status[child.id] === 'blocked').length,
      outside: 0,
    }
  }

  return { status, flow: {}, leverage: {}, upstream: {}, rarity: {}, groups, snoozed: {}, pulls: {} }
}
