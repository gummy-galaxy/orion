import { DitheringShapes, DitheringTypes, type DitheringShape, type DitheringUniforms } from '@paper-design/shaders'
import type { CardView } from '../cardView'
import type { InkPair } from './frameColor'

type ArtKind = Exclude<CardView['kind'], 'note'>
type ArtLayer = DitheringUniforms & { frame: number }
export type CardArtSpec = { angle: number; back: readonly [string, string]; base: ArtLayer; top: ArtLayer }

const SHAPES: Record<ArtKind | 'banner', readonly DitheringShape[]> = {
  pr: ['warp', 'simplex', 'swirl'],
  step: ['wave', 'ripple', 'simplex'],
  placeholder: ['dots'],
  gate: ['sphere'],
  banner: ['warp', 'simplex', 'swirl', 'ripple'],
}
const NIGHT = [10, 6, 30]

function createSeededRandom(text: string): () => number {
  let hash = 2166136261

  for (let index = 0; index < text.length; index++) hash = Math.imul(hash ^ text.charCodeAt(index), 16777619)

  return () => {
    hash = Math.imul(hash ^ (hash >>> 15), 2246822507)
    hash = Math.imul(hash ^ (hash >>> 13), 3266489909)

    return ((hash ^= hash >>> 16) >>> 0) / 4294967296
  }
}

function pickRandom<T>(random: () => number, values: readonly T[]): T {
  return values[Math.floor(random() * values.length)]
}

function getRgbChannels(ink: string): [number, number, number] {
  const value = Number.parseInt(ink.slice(1), 16)

  return [(value >> 16) & 255, (value >> 8) & 255, value & 255]
}

function getShadedInk(ink: string, amount: number): string {
  return `rgb(${getRgbChannels(ink)
    .map((value, index) => Math.round(value + (NIGHT[index] - value) * amount))
    .join(' ')})`
}

function getShaderColor(ink: string, alpha: number): [number, number, number, number] {
  const [red, green, blue] = getRgbChannels(ink)

  return [red / 255, green / 255, blue / 255, alpha]
}

function createArtLayer(random: () => number, shape: DitheringShape, ink: string, alpha: number, pixelSize: number): ArtLayer {
  return {
    u_colorBack: [0, 0, 0, 0],
    u_colorFront: getShaderColor(ink, alpha),
    u_shape: DitheringShapes[shape],
    u_type: DitheringTypes[pickRandom(random, ['4x4', '8x8', '8x8', 'random'] as const)],
    u_pxSize: pixelSize,
    u_fit: 0,
    u_scale: shape === 'sphere' ? 0.9 + random() * 0.25 : 0.45 + random() * 0.9,
    u_rotation: random() * 360,
    u_offsetX: shape === 'sphere' ? -0.15 + random() * 0.3 : (random() - 0.5) * 0.8,
    u_offsetY: shape === 'sphere' ? 0.1 + random() * 0.15 : (random() - 0.5) * 0.8,
    u_originX: 0.5,
    u_originY: 0.5,
    u_worldWidth: 0,
    u_worldHeight: 0,
    frame: random() * 60000,
  }
}

export function getCardArtSpec(seed: string, kind: ArtKind, inks: InkPair): CardArtSpec {
  const random = createSeededRandom(seed)
  const [firstInk, secondInk] = inks
  const shapes = SHAPES[kind]
  const topShape =
    kind === 'gate'
      ? 'ripple'
      : pickRandom(
          random,
          SHAPES.banner.filter((shape) => shape !== shapes[0]),
        )

  return {
    angle: random() * Math.PI * 2,
    back: [getShadedInk(firstInk, 0.86), getShadedInk(secondInk, 0.62)],
    base: createArtLayer(random, pickRandom(random, shapes), firstInk, kind === 'placeholder' ? 0.7 : 1, kind === 'placeholder' ? 3 : 2),
    top: createArtLayer(random, topShape, secondInk, kind === 'gate' ? 0.55 : 0.85, 2),
  }
}
