import { describe, expect, it } from 'vitest'
import { reconnectLink } from './reconnect'
import type { Link } from './model'

const blocks = (from: string, to: string, extra: Partial<Link> = {}): Link => ({
  id: `${from}>${to}`,
  from,
  to,
  kind: 'blocks',
  ...extra,
})

describe('reconnect a link', () => {
  it('moves the target end and renames the link after its new pair', () => {
    const links = [blocks('a', 'b'), blocks('c', 'd')]

    expect(reconnectLink(links, 'a>b', { to: 'c' })).toEqual([blocks('a', 'c'), blocks('c', 'd')])
  })

  it('moves the source end', () => {
    expect(reconnectLink([blocks('a', 'b')], 'a>b', { from: 'c' })).toEqual([blocks('c', 'b')])
  })

  it('keeps a related link related, under the id the CLI gives related links', () => {
    const related: Link = { id: 'a~b', from: 'a', to: 'b', kind: 'related' }

    expect(reconnectLink([related], 'a~b', { to: 'c' })).toEqual([{ id: 'a~c', from: 'a', to: 'c', kind: 'related' }])
  })

  it('keeps the label and drops a derived origin', () => {
    const links = [blocks('a', 'b', { label: 'HTTP', origin: 'stack' })]

    expect(reconnectLink(links, 'a>b', { to: 'c' })).toEqual([blocks('a', 'c', { label: 'HTTP' })])
  })

  it('leaves the links alone when nothing would change', () => {
    const links = [blocks('a', 'b'), blocks('c', 'a')]

    expect(reconnectLink(links, 'missing', { to: 'c' })).toBe(links)
    expect(reconnectLink(links, 'a>b', { to: 'b' })).toBe(links)
    expect(reconnectLink(links, 'a>b', {})).toBe(links)
    expect(reconnectLink(links, 'a>b', { to: 'a' })).toBe(links)
  })

  it("won't join a pair another link already joins, whichever way it runs", () => {
    const links = [blocks('a', 'b'), blocks('c', 'a')]

    expect(reconnectLink(links, 'a>b', { to: 'c' })).toBe(links)
  })
})
