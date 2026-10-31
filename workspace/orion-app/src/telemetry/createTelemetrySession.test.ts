import { expect, test } from 'vitest'
import { createTelemetrySession, MAX_SAMPLES } from './createTelemetrySession'

const SIZE = { card_count: 40, group_count: 3 }

const createClock = () => {
  let time = 1000

  return { now: () => time, advance: (ms: number) => (time += ms) }
}

test('a stretch reports time in each tool and what was made', () => {
  const clock = createClock()
  const session = createTelemetrySession(clock.now)

  clock.advance(1000)
  session.setTool('sticker')
  session.count('stickers_placed')
  session.count('stickers_placed')
  clock.advance(500)
  session.setTool('select')
  session.count('pastes')
  clock.advance(250)

  const [features] = session.takeEvents(SIZE)

  expect(features).toEqual({
    name: 'features_used',
    properties: {
      session_ms: 1750,
      select_tool_ms: 1250,
      pan_tool_ms: 0,
      comment_tool_ms: 0,
      sticker_tool_ms: 500,
      stickers_placed: 2,
      pastes: 1,
    },
  })
})

test('timings are summarized with the canvas size, and each stretch starts over', () => {
  const clock = createClock()
  const session = createTelemetrySession(clock.now)

  for (const gap of [16, 17, 50]) session.record('pan_frame', gap)

  session.record('layout', 120)

  // A whole canvas shape comes in, and only the counts the event lists go out.
  const events = session.takeEvents({ ...SIZE, nesting_depth: 2, link_count: 9 } as typeof SIZE)

  expect(events.slice(1)).toEqual([
    { name: 'performance_summarized', properties: { metric: 'pan_frame', sample_count: 3, p50_ms: 17, p95_ms: 50, max_ms: 50, ...SIZE } },
    { name: 'performance_summarized', properties: { metric: 'layout', sample_count: 1, p50_ms: 120, p95_ms: 120, max_ms: 120, ...SIZE } },
  ])

  clock.advance(100)

  expect(session.takeEvents(SIZE)).toEqual([
    { name: 'features_used', properties: { session_ms: 100, select_tool_ms: 100, pan_tool_ms: 0, comment_tool_ms: 0, sticker_tool_ms: 0 } },
  ])
})

test('samples past the cap still count toward sample_count', () => {
  const session = createTelemetrySession(createClock().now)

  for (let index = 0; index < MAX_SAMPLES + 5; index++) session.record('zoom_frame', 16)

  expect(session.takeEvents(SIZE)[1].properties?.sample_count).toBe(MAX_SAMPLES + 5)
})
