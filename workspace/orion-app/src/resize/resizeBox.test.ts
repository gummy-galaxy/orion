import { expect, test } from 'vitest'
import { resizeBox } from './resizeBox'

const start = { x: 100, y: 100, width: 400, height: 300 }
const minimum = { width: 280, height: 182 }

test('moves the right and bottom edges by the drag', () => {
  expect(resizeBox(start, { right: true, bottom: true }, { x: 50, y: -20 }, minimum)).toEqual({
    x: 100,
    y: 100,
    width: 450,
    height: 280,
  })
})

test('holds the right and bottom edges while the left and top move', () => {
  expect(resizeBox(start, { left: true, top: true }, { x: -50, y: 40 }, minimum)).toEqual({
    x: 50,
    y: 140,
    width: 450,
    height: 260,
  })
})

test('stops at the minimum size without moving the edges it holds', () => {
  expect(resizeBox(start, { left: true }, { x: 1000, y: 0 }, minimum)).toEqual({
    x: 220,
    y: 100,
    width: 280,
    height: 300,
  })
})

test('ignores the axis a handle does not move', () => {
  expect(resizeBox(start, { right: true }, { x: 10, y: 500 }, minimum)).toEqual({ ...start, width: 410 })
})
