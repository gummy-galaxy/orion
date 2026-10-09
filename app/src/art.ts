import {
  GrainGradientShapes,
  ShaderFitOptions,
  ShaderMount,
  defaultObjectSizing,
  getShaderColorFromString,
  getShaderNoiseTexture,
  grainGradientFragmentShader,
  type ShaderMountUniforms,
} from '@paper-design/shaders'

/**
 * Generated card art. Browsers allow only a handful of WebGL contexts per page, so instead of a shader per card,
 * one hidden shader paints each card's art in turn and hands back a still image.
 */

const ART_W = 184
const ART_H = 92
const SHAPES = ['corners', 'wave', 'ripple', 'blob', 'sphere'] as const

/** Which theme color tints the art for each status. */
const TONE: Record<string, string> = {
  ready: '--accent',
  active: '--st-active',
  review: '--st-review',
  blocked: '--st-blocked',
  deferred: '--st-todo',
  done: '--edge',
  note: '--note-edge',
}

function seeded(text: string) {
  let h = 2166136261

  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619)

  return () => {
    h = Math.imul(h ^ (h >>> 15), 2246822507)
    h = Math.imul(h ^ (h >>> 13), 3266489909)

    return ((h ^= h >>> 16) >>> 0) / 4294967296
  }
}

/** A color's hue (degrees) and saturation (percent), which is all the art borrows from a source. */
export type Hue = { h: number; s: number }

function hslOf(r: number, g: number, b: number): Hue & { l: number } {
  const max = Math.max(r, g, b)
  const min = Math.min(r, g, b)
  const l = (max + min) / 2
  const d = max - min

  if (!d) return { h: 0, s: 0, l: l * 100 }

  const s = d / (1 - Math.abs(2 * l - 1))
  const h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4

  return { h: (h * 60 + 360) % 360, s: s * 100, l: l * 100 }
}

function hueOf(hex: string): Hue {
  const n = parseInt(hex.replace('#', '').slice(0, 6), 16)

  return hslOf(((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255)
}

const clamp = (v: number) => Math.round(Math.max(0, Math.min(100, v)))
const hsl = (h: number, s: number, l: number) => `hsl(${Math.round(h + 360) % 360}, ${clamp(s)}%, ${clamp(l)}%)`

function uniformsFor(seed: string, tone: string, palette: Hue[] | null, noise: HTMLImageElement): { uniforms: ShaderMountUniforms; frame: number } {
  const rand = seeded(seed)
  const css = getComputedStyle(document.documentElement)
  const base = palette?.[0] ?? hueOf(css.getPropertyValue(TONE[tone] ?? '--st-todo').trim() || '#5d6d75')
  const sat = base.s < 20 ? base.s : Math.max(base.s, 70)
  const drift = (rand() - 0.5) * 40
  const pick = (i: number, shift: number, scale: number): Hue =>
    palette?.[i] ? { h: palette[i].h, s: Math.max(palette[i].s, 60) } : { h: base.h + shift + drift, s: sat * scale }
  const tints = [pick(0, 0, 1), pick(1, 45, 1), pick(2, -40, 0.9), pick(3, 160, 0.7)]
  const colors = tints.map((t, i) => hsl(t.h, t.s, [55, 72, 42, 80][i]))
  const shape = SHAPES[Math.floor(rand() * SHAPES.length)]

  return {
    frame: rand() * 60_000,
    uniforms: {
      u_colorBack: getShaderColorFromString(hsl(base.h - 20, sat * 0.7, 22)),
      u_colors: colors.map((c) => getShaderColorFromString(c)),
      u_colorsCount: colors.length,
      u_softness: 0.4 + rand() * 0.5,
      u_intensity: 0.3 + rand() * 0.4,
      u_noise: 0.15 + rand() * 0.25,
      u_shape: GrainGradientShapes[shape],
      u_noiseTexture: noise,
      u_fit: ShaderFitOptions[defaultObjectSizing.fit],
      u_scale: 0.8 + rand() * 0.5,
      u_rotation: rand() * 360,
      u_offsetX: (rand() - 0.5) * 0.3,
      u_offsetY: (rand() - 0.5) * 0.3,
      u_worldWidth: defaultObjectSizing.worldWidth,
      u_worldHeight: defaultObjectSizing.worldHeight,
    },
  }
}

const frame = () => new Promise((done) => requestAnimationFrame(done))

let painter: Promise<{ mount: ShaderMount; noise: HTMLImageElement }> | null = null

function getPainter() {
  painter ??= (async () => {
    const noise = getShaderNoiseTexture()!

    if (!noise.complete) await new Promise((done) => (noise.onload = done))

    const host = document.createElement('div')

    host.setAttribute('aria-hidden', 'true')
    Object.assign(host.style, {
      position: 'fixed',
      left: '0',
      top: '0',
      width: `${ART_W}px`,
      height: `${ART_H}px`,
      opacity: '0',
      pointerEvents: 'none',
      zIndex: '-1',
    })
    document.body.append(host)
    const { uniforms } = uniformsFor('', 'ready', null, noise)
    const mount = new ShaderMount(host, grainGradientFragmentShader, uniforms, { preserveDrawingBuffer: true }, 0, 0, 2)
    const canvas = mount.canvasElement

    for (let i = 0; i < 60 && canvas.width === 300 && canvas.height === 150; i++) await frame()

    return { mount, noise }
  })()

  return painter
}

const baked = new Map<string, Promise<string>>()
let queue: Promise<unknown> = Promise.resolve()

/**
 * A still of a card's generated art, as a data URL, in the colors of its source when it has some and its status
 * otherwise. The same inputs always paint the same picture.
 */
export function bakeArt(seed: string, tone: string, palette: Hue[] | null): Promise<string> {
  const theme = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  const key = `${theme}:${tone}:${seed}:${palette?.map((c) => `${Math.round(c.h)}/${Math.round(c.s)}`).join(',') ?? ''}`
  let found = baked.get(key)

  if (!found) {
    found = queue.then(async () => {
      const { mount, noise } = await getPainter()
      const art = uniformsFor(seed, tone, palette, noise)

      mount.setUniforms(art.uniforms)
      mount.setFrame(art.frame)

      return mount.canvasElement.toDataURL('image/webp', 0.85)
    })
    queue = found.catch(() => undefined)
    baked.set(key, found)
  }

  return found
}

const HUE_BINS = 12

/** The few strongest colors in an image or video frame, strongest first, or null when it's mostly gray. */
export async function paletteOf(src: string, video: boolean): Promise<Hue[] | null> {
  const media = video ? document.createElement('video') : new Image()

  media.src = src

  if (media instanceof HTMLVideoElement) {
    media.muted = true
    media.preload = 'auto'
    await new Promise((done, fail) => {
      media.onloadeddata = done
      media.onerror = fail
    })
  } else {
    await media.decode()
  }

  const canvas = document.createElement('canvas')

  canvas.width = 64
  canvas.height = 32
  const ctx = canvas.getContext('2d', { willReadFrequently: true })!

  ctx.drawImage(media, 0, 0, canvas.width, canvas.height)
  const { data } = ctx.getImageData(0, 0, canvas.width, canvas.height)
  const bins = Array.from({ length: HUE_BINS }, () => ({ weight: 0, x: 0, y: 0, s: 0 }))
  let total = 0

  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] < 200) continue

    const c = hslOf(data[i] / 255, data[i + 1] / 255, data[i + 2] / 255)

    if (c.s < 25 || c.l < 12 || c.l > 90) continue

    const bin = bins[Math.round(c.h / (360 / HUE_BINS)) % HUE_BINS]
    const weight = c.s / 100
    const angle = (c.h * Math.PI) / 180

    bin.weight += weight
    bin.x += Math.cos(angle) * weight
    bin.y += Math.sin(angle) * weight
    bin.s += c.s * weight
    total += weight
  }

  const strong = bins
    .filter((b) => b.weight > total * 0.06 && b.weight > 8)
    .sort((a, b) => b.weight - a.weight)
    .slice(0, 3)
    .map((b) => ({ h: ((Math.atan2(b.y, b.x) * 180) / Math.PI + 360) % 360, s: b.s / b.weight }))

  return strong.length ? strong : null
}
