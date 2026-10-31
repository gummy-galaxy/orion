import { describe, expect, it } from 'vitest'
import { emptyTrail, leave, travel, type Place } from './navigation'

const at = (root: string | null, focus: string | null = null, x = 0): Place => ({
  root,
  focus,
  selected: [],
  viewport: { x, y: 0, zoom: 1 },
})
const always = () => true

describe('navigation', () => {
  it('goes back and forward through places', () => {
    let trail = leave(emptyTrail(), at(null))

    trail = leave(trail, at('group'))

    const back = travel(trail, at('group', 'card'), 'back', always)!

    expect(back.place).toEqual(at('group'))

    const again = travel(back.trail, back.place, 'back', always)!

    expect(again.place).toEqual(at(null))
    expect(travel(again.trail, again.place, 'back', always)).toBeNull()

    const forward = travel(again.trail, again.place, 'forward', always)!

    expect(forward.place).toEqual(at('group'))
    expect(travel(forward.trail, forward.place, 'forward', always)!.place).toEqual(at('group', 'card'))
  })

  it('drops the forward places when you go somewhere new', () => {
    const trail = leave(leave(emptyTrail(), at(null)), at('a'))
    const back = travel(trail, at('b'), 'back', always)!

    expect(back.trail.forward).toHaveLength(1)
    expect(leave(back.trail, back.place).forward).toEqual([])
  })

  it('records one place when several steps leave it at once', () => {
    const trail = leave(leave(emptyTrail(), at('a')), at('a'))

    expect(trail.back).toHaveLength(1)
    expect(leave(trail, at('a', null, 300)).back).toHaveLength(2)
  })

  it('skips places whose group or card is gone', () => {
    const trail = leave(leave(leave(emptyTrail(), at(null)), at('removed')), at('kept', 'removed'))
    const back = travel(trail, at('kept'), 'back', (place) => place.root !== 'removed' && place.focus !== 'removed')!

    expect(back.place).toEqual(at(null))
    expect(back.trail.back).toEqual([])
    expect(back.trail.forward).toEqual([at('kept')])
  })

  it('keeps a bounded trail', () => {
    let trail = emptyTrail()

    for (let i = 0; i < 5; i++) trail = leave(trail, at(null, null, i * 100), 3)

    expect(trail.back.map((place) => place.viewport.x)).toEqual([200, 300, 400])
  })
})
