import type { PosterInput, PosterShape, PosterSpec } from './posterSpec'
import { getPosterSpec } from './posterSpec'

const BAYER4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const MAX_CACHE = 300
const cache = new Map<string, string>()
const pending = new Map<string, { input: PosterInput; width: number; height: number; listeners: Set<(image: string | null) => void> }>()
let scheduled = false
let canvasUnavailable = false

function getKey(input: PosterInput, width: number, height: number): string {
  return JSON.stringify([input.artSeed, input.kind, input.status, input.upstream, input.leverage, width, height])
}

function drawShape(context: CanvasRenderingContext2D, shape: PosterShape): void {
  const attributes = shape.attrs

  context.save()
  context.globalAlpha = shape.alpha ?? 1
  context.globalCompositeOperation = shape.blend ?? 'source-over'

  if (shape.rotate) {
    const [angle, x, y] = shape.rotate

    context.translate(x, y)
    context.rotate((angle * Math.PI) / 180)
    context.translate(-x, -y)
  }

  let path: Path2D

  if (shape.tag === 'path') path = new Path2D(String(attributes.d))
  else {
    path = new Path2D()

    if (shape.tag === 'rect') path.rect(Number(attributes.x), Number(attributes.y), Number(attributes.width), Number(attributes.height))

    if (shape.tag === 'circle') path.arc(Number(attributes.cx), Number(attributes.cy), Number(attributes.r), 0, Math.PI * 2)

    if (shape.tag === 'polygon') {
      const points = String(attributes.points)
        .split(/\s+/)
        .map((part) => part.split(',').map(Number))

      path.moveTo(points[0][0], points[0][1])

      for (const [x, y] of points.slice(1)) path.lineTo(x, y)

      path.closePath()
    }
  }

  if (attributes.fill && attributes.fill !== 'none') {
    context.fillStyle = String(attributes.fill)
    context.fill(path)
  }

  const stroke = shape.stroke ?? attributes.stroke

  if (stroke && stroke !== 'none') {
    context.strokeStyle = String(stroke)
    context.lineWidth = Math.max(3, shape.width ?? Number(attributes['stroke-width'] ?? 3))
    context.lineJoin = 'round'
    context.stroke(path)
  }

  context.restore()
}

function applyOrderedDither(context: CanvasRenderingContext2D, width: number, height: number): void {
  const image = context.getImageData(0, 0, width, height)
  const pixels = image.data

  for (let y = 0; y < height; y += 2)
    for (let x = 0; x < width; x += 2) {
      const source = (Math.min(y + 1, height - 1) * width + Math.min(x + 1, width - 1)) * 4
      const threshold = (BAYER4[(Math.floor(y / 2) % 4) * 4 + (Math.floor(x / 2) % 4)] + 0.5) / 16
      const dark = 0.2126 * pixels[source] + 0.7152 * pixels[source + 1] + 0.0722 * pixels[source + 2] < 35

      for (let channel = 0; channel < 3; channel++) {
        const value = pixels[source + channel]
        const low = Math.floor(value / 64) * 64
        const result = dark ? value : Math.min(255, (value - low) / 64 > threshold ? low + 64 : low)

        for (let deltaY = 0; deltaY < 2 && y + deltaY < height; deltaY++)
          for (let deltaX = 0; deltaX < 2 && x + deltaX < width; deltaX++) {
            pixels[((y + deltaY) * width + x + deltaX) * 4 + channel] = result
          }
      }
    }

  context.putImageData(image, 0, 0)
}

function paintPoster(spec: PosterSpec, width: number, height: number): string | null {
  if (canvasUnavailable || typeof document === 'undefined' || typeof Path2D === 'undefined') return null

  try {
    const canvas = document.createElement('canvas')

    canvas.width = width
    canvas.height = height
    const context = canvas.getContext('2d', { willReadFrequently: true })

    if (!context) {
      canvasUnavailable = true

      return null
    }

    context.scale(width / 256, height / 160)

    for (const shape of spec.shapes) drawShape(context, shape)

    applyOrderedDither(context, width, height)

    return canvas.toDataURL('image/png')
  } catch {
    canvasUnavailable = true

    return null
  }
}

function processQueue(): void {
  scheduled = false

  for (const [key, task] of [...pending].slice(0, 3)) {
    pending.delete(key)
    const image = paintPoster(getPosterSpec(task.input), task.width, task.height)

    if (image) {
      cache.delete(key)
      cache.set(key, image)

      if (cache.size > MAX_CACHE) cache.delete(cache.keys().next().value!)
    }

    for (const listener of task.listeners) listener(image)
  }

  if (pending.size) scheduleQueue()
}

function scheduleQueue(): void {
  if (scheduled) return

  scheduled = true

  if (typeof requestIdleCallback === 'function') requestIdleCallback(processQueue, { timeout: 120 })
  else setTimeout(processQueue, 16)
}

export function getCachedPoster(input: PosterInput, width: number, height: number): string | null {
  const key = getKey(input, width, height)
  const image = cache.get(key) ?? null

  return image
}

export function requestPoster(input: PosterInput, width: number, height: number, listener: (image: string | null) => void): () => void {
  const key = getKey(input, width, height)
  const cached = getCachedPoster(input, width, height)

  if (cached || canvasUnavailable || typeof document === 'undefined' || typeof Path2D === 'undefined') {
    if (cached) {
      cache.delete(key)
      cache.set(key, cached)
    }

    listener(cached)

    return () => undefined
  }

  const task = pending.get(key) ?? { input, width, height, listeners: new Set<(image: string | null) => void>() }

  task.listeners.add(listener)
  pending.set(key, task)
  scheduleQueue()

  return () => {
    task.listeners.delete(listener)

    if (!task.listeners.size) pending.delete(key)
  }
}
