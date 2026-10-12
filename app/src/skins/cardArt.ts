import type { CardView } from '../cardView'
import { hashText } from './frameColor'

type ArtKind = Exclude<CardView['kind'], 'note'>
type CardArt = { markup: string; palettePick: number; hueShift: number }

const artCache = new Map<string, CardArt>()
const orderedDither = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const motifPaths: Record<ArtKind, string> = {
  step: 'M-27 14 -7 -10 5 3 27 -21 M6 3v-17h20',
  pr: 'M-29 -16C-5 -16 -5 16 29 16 M-29 16C-5 16 -5 -16 29 -16',
  placeholder: 'M-27 -19h54v38h-54z M-13 -9h26v18h-26z',
  gate: 'M0 -27 29 0 0 27 -29 0Z M0 -13 14 0 0 13 -14 0Z',
}

function getShapeStrength(kind: ArtKind, x: number, y: number, focusX: number, focusY: number): number {
  const distance = Math.hypot((x - focusX) / 72, (y - focusY) / 55)

  if (kind === 'placeholder') return Math.max(0, 0.8 - distance) + ((Math.floor(x / 19) + Math.floor(y / 19)) % 2) * 0.1

  if (kind === 'gate') return Math.max(0, 0.9 - Math.abs(distance - 0.45) * 1.2)

  if (kind === 'pr') return Math.max(0, 0.85 - Math.abs(y - (focusY + (x - focusX) * 0.35)) / 42)

  return Math.max(0, 0.85 - Math.abs(y - (focusY - (x - focusX) * 0.35)) / 42)
}

export function getCardArt(seed: string, kind: ArtKind): CardArt {
  const key = `${kind}\u0000${seed}`
  const cached = artCache.get(key)

  if (cached) return cached

  let randomState = hashText(key) || 1

  const random = () => {
    randomState ^= randomState << 13
    randomState ^= randomState >>> 17
    randomState ^= randomState << 5

    return (randomState >>> 0) / 4294967296
  }

  const palettePick = Math.floor(random() * 3)
  const hueShift = Math.round(random() * 28) - 14
  const cellSize = [5, 6, 7, 8][Math.floor(random() * 4)]
  const matrixColumn = Math.floor(random() * 4)
  const matrixRow = Math.floor(random() * 4)
  const focusX = 25 + Math.floor(random() * 78)
  const focusY = 18 + Math.floor(random() * 60)
  const dots: string[] = []

  for (let y = 0, row = 0; y < 96; y += cellSize, row++) {
    for (let x = 0, column = 0; x < 128; x += cellSize, column++) {
      const threshold = orderedDither[((row + matrixRow) % 4) * 4 + ((column + matrixColumn) % 4)] / 16
      const strength = getShapeStrength(kind, x, y, focusX, focusY) * 0.76 + random() * 0.22

      if (strength > threshold) dots.push(`M${x} ${y}h${cellSize - 1}v${cellSize - 1}h-${cellSize - 1}z`)
    }
  }

  const motifCount = (kind === 'gate' ? 1 : 2) + Math.floor(random() * (kind === 'step' ? 3 : 2))
  const motifs: string[] = []

  for (let index = 0; index < motifCount; index++) {
    const x = 24 + Math.floor(random() * 82)
    const y = 19 + Math.floor(random() * 58)
    const scale = (55 + Math.floor(random() * 56)) / 100
    const rotation = Math.floor(random() * 91) - 45

    motifs.push(`<path d="${motifPaths[kind]}" transform="translate(${x} ${y}) rotate(${rotation}) scale(${scale})"/>`)
  }

  const accentX = 13 + Math.floor(random() * 102)
  const accentY = 12 + Math.floor(random() * 72)
  const accentSize = 9 + Math.floor(random() * 11)
  const accentRotation = Math.floor(random() * 90)
  const accent =
    kind === 'gate'
      ? `M${accentX} ${accentY - accentSize}l${accentSize} ${accentSize} -${accentSize} ${accentSize} -${accentSize} -${accentSize}z`
      : kind === 'placeholder'
        ? `M${accentX - accentSize} ${accentY - accentSize}h${accentSize * 2}v${accentSize * 2}h-${accentSize * 2}z`
        : `M${accentX} ${accentY - accentSize}l${accentSize} ${accentSize * 2}h-${accentSize * 2}z`
  const markup = `<rect width="128" height="96" fill="var(--trading-art-base)"/><path d="${accent}" transform="rotate(${accentRotation} ${accentX} ${accentY})" fill="var(--trading-art-accent)"/><path d="${dots.join('')}" fill="var(--trading-art-ink)"/><g fill="none" stroke="var(--trading-art-line)" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">${motifs.join('')}</g>`
  const art = { markup, palettePick, hueShift }

  if (artCache.size >= 2048) artCache.delete(artCache.keys().next().value!)

  artCache.set(key, art)

  return art
}
