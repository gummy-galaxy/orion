import { TASK_HEIGHT, TASK_WIDTH } from './geometry'
import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  adoptedPrint,
  clearFocus,
  compactDoc,
  displayedDoc,
  fetchRemote,
  fingerprint,
  reportFocus,
  storedPrint,
  watchQuery,
  type Remote,
} from './persist'
import { pushAside } from './pushAside'
import { skinOf } from './skins'

afterEach(() => vi.unstubAllGlobals())

it('reads the requested workspace during a conflict retry', async () => {
  const remote = { version: 2, revision: 3, settings: {}, nodes: [], links: [] }
  const fetchMock = vi.fn().mockResolvedValue({
    ok: true,
    headers: new Headers({ 'content-type': 'application/json' }),
    json: async () => remote,
  })

  vi.stubGlobal('fetch', fetchMock)

  expect(await fetchRemote('other')).toEqual(remote)
  expect(fetchMock).toHaveBeenCalledWith('/api/orion', { headers: { 'x-orion-canvas': 'other' } })
})

it('reports the selection with a tab and workspace', () => {
  const fetchMock = vi.fn().mockResolvedValue({ ok: true })

  vi.stubGlobal('fetch', fetchMock)

  reportFocus({ open: 'group', selected: ['card'] }, 'planning')

  const [url, options] = fetchMock.mock.calls[0]

  expect(url).toBe('/api/focus')
  expect(options.method).toBe('POST')
  expect(JSON.parse(options.body)).toEqual({
    tab: expect.any(String),
    canvas: 'planning',
    open: 'group',
    selected: ['card'],
  })
})

it('sends a closing report for the same workspace', async () => {
  const sendBeacon = vi.fn()

  vi.stubGlobal('navigator', { sendBeacon })

  clearFocus('planning')

  const [url, body] = sendBeacon.mock.calls[0]

  expect(url).toBe('/api/focus')
  expect(JSON.parse(await (body as Blob).text())).toEqual({ tab: expect.any(String), canvas: 'planning', closed: true })
})

/** Stands in for the event socket: records what the app sends and lets a test open it and answer. */
class FakeSocket {
  static opened: FakeSocket[] = []
  readonly OPEN = 1
  readyState = 0
  sent: unknown[] = []
  onopen?: () => void
  onmessage?: (message: { data: string }) => void
  onclose?: () => void
  onerror?: () => void

  constructor() {
    FakeSocket.opened.push(this)
  }

  send(data: string) {
    this.sent.push(JSON.parse(data))
  }

  close() {
    this.readyState = 3
    this.onclose?.()
  }

  open() {
    this.readyState = this.OPEN
    this.onopen?.()
  }

  answer(data: unknown) {
    this.onmessage?.({ data: JSON.stringify({ type: 'custom', event: 'orion:query', data }) })
  }
}

it('keeps a query open over the event socket until it is dropped', () => {
  FakeSocket.opened = []
  vi.stubGlobal('WebSocket', FakeSocket)
  vi.stubGlobal('location', { protocol: 'http:', host: 'localhost' })

  const answers: unknown[] = []
  const stop = watchQuery({ where: 'kind = "step"', all: true }, (answer) => answers.push(answer))
  const socket = FakeSocket.opened[0]

  socket.open()
  const [sent] = socket.sent as { id: string }[]

  expect(sent).toEqual({ type: 'query', id: sent.id, where: 'kind = "step"', all: true })

  socket.answer({ id: 'someone-else', canvas: 'default', revision: 1, total: 0, offset: 0, rows: [] })
  socket.answer({ id: sent.id, canvas: 'default', revision: 2, total: 0, offset: 0, rows: [] })

  expect(answers).toEqual([{ canvas: 'default', revision: 2, total: 0, offset: 0, rows: [] }])

  stop()

  expect(socket.sent.at(-1)).toEqual({ type: 'unquery', id: sent.id })
  expect(socket.readyState).toBe(3)
})

describe('adopting a server document', () => {
  const CLASSIC = { width: TASK_WIDTH, height: TASK_HEIGHT }
  const TRADING = skinOf('trading').size

  // The CLI's JSON encoder writes keys in hash order, so positions come back with `y` first.
  const serverDoc = JSON.parse(`{
    "revision": 7,
    "settings": {},
    "nodes": [
      {
        "id": "loose", "type": "task", "position": { "y": 40, "x": 900 },
        "data": { "status": "todo", "label": "Loose card", "kind": "task", "type": "step" }
      },
      {
        "id": "picture", "type": "image", "position": { "y": 600, "x": 0 }, "width": 200, "height": 150,
        "data": { "kind": "image", "label": "Picture", "asset": "a", "canvas": "default" }
      },
      {
        "id": "group", "type": "cluster", "position": { "y": 0, "x": 0 }, "width": 280, "height": 182,
        "data": { "label": "Group", "kind": "cluster" }
      },
      {
        "id": "inside", "type": "task", "parentId": "group", "position": { "y": 78, "x": 32 },
        "data": { "kind": "task", "label": "Inside", "type": "step", "status": "active" }
      },
      {
        "id": "aside", "type": "task", "position": { "y": 300, "x": 900 },
        "data": { "kind": "task", "label": "a\\nb\\nc\\nd\\ne\\nf", "type": "note", "status": "todo" }
      }
    ],
    "links": [{ "to": "inside", "kind": "blocks", "id": "link", "from": "loose" }]
  }`) as Remote

  for (const [skin, cardSize] of [
    ['classic', CLASSIC],
    ['trading', TRADING],
  ] as const) {
    it(`leaves nothing to save with ${skin} cards`, () => {
      const adopted = displayedDoc(serverDoc, cardSize)

      expect(storedPrint(adopted, cardSize)).toBe(adoptedPrint(serverDoc, cardSize))
    })

    it(`leaves nothing to save when the same document arrives again with ${skin} cards`, () => {
      const shown = displayedDoc(serverDoc, cardSize).nodes
      const again = displayedDoc(serverDoc, cardSize)
      const nodes = pushAside(shown, again.nodes, cardSize)

      expect(storedPrint({ ...again, nodes }, cardSize)).toBe(adoptedPrint(serverDoc, cardSize))
    })
  }

  it('stores the height it measures for notes at the classic size, and none for work cards', () => {
    const stored = JSON.parse(storedPrint(displayedDoc(serverDoc, TRADING), TRADING)) as Remote
    const nodes = new Map(stored.nodes.map((node) => [node.id, node]))

    expect(nodes.get('aside')).toMatchObject({ width: TASK_WIDTH, height: 136 })
    expect(nodes.get('loose')?.height).toBeUndefined()
  })

  it('saves positions that moved aside', () => {
    const shown = displayedDoc(serverDoc, TRADING)
    const nodes = shown.nodes.map((node) =>
      node.id === 'loose' ? { ...node, position: { x: node.position.x + 400, y: node.position.y } } : node,
    )

    expect(storedPrint({ ...shown, nodes }, TRADING)).not.toBe(adoptedPrint(serverDoc, TRADING))
  })
})

it('fingerprints a document the same however its position keys are ordered', () => {
  // The server returns positions as y then x; the canvas builds x then y. Both are the same document.
  const canvas = compactDoc({
    nodes: [{ id: 'a', type: 'task', position: { x: 10, y: 20 }, data: { kind: 'task', label: 'a' } }] as never,
    links: [],
  })
  const server = compactDoc({
    nodes: [{ id: 'a', type: 'task', position: { y: 20, x: 10 }, data: { label: 'a', kind: 'task' } }] as never,
    links: [],
  })

  expect(fingerprint(canvas)).toBe(fingerprint(server))
})
