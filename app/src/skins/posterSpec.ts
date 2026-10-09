import type { CardView } from '../cardView'
import { hashText } from './frameColor'

export type PosterInput = Pick<CardView, 'artSeed' | 'kind' | 'status' | 'upstream' | 'leverage'>
export type PosterShape = {
  tag: 'rect' | 'circle' | 'polygon' | 'path'
  attrs: Record<string, string | number>
  alpha?: number
  blend?: 'multiply' | 'screen'
  rotate?: [number, number, number]
  stroke?: string
  width?: number
}
export type PosterSpec = { template: number; shapes: PosterShape[]; excessUpstream: number }

type Placement = [number, number, number, number]
type Palette = { light: string; deep: string; accent: string; hero: string; balance: number }

const BACK = '#0d0a24'
const INKS = ['#18d6c0', '#3b6cff', '#b45cff', '#ff8fa3', '#ffb347', '#ff5e7e', '#d94dff']
const KIND_COLOR: Record<CardView['kind'], string> = {
  step: '#9ee2d3',
  pr: '#8eb2ff',
  placeholder: '#a8d5ff',
  gate: '#ffcb82',
  note: '#ffddaf',
}

function randomFor(seed: string): () => number {
  let hash = hashText(seed)

  return () => {
    hash = Math.imul(hash ^ (hash >>> 15), 2246822507)
    hash = Math.imul(hash ^ (hash >>> 13), 3266489909)

    return ((hash ^= hash >>> 16) >>> 0) / 4294967296
  }
}

function mix(first: string, second: string, amount: number): string {
  return `#${[1, 3, 5]
    .map((index) =>
      Math.round(parseInt(first.slice(index, index + 2), 16) * (1 - amount) + parseInt(second.slice(index, index + 2), 16) * amount)
        .toString(16)
        .padStart(2, '0'),
    )
    .join('')}`
}

const round = (value: number) => Math.round(value * 10) / 10
const point = (x: number, y: number) => `${round(x)},${round(y)}`
const rect = (x: number, y: number, width: number, height: number, fill: string, options: Partial<PosterShape> = {}): PosterShape => ({
  tag: 'rect',
  attrs: { x, y, width, height, fill },
  ...options,
})
const circle = (cx: number, cy: number, r: number, fill: string, options: Partial<PosterShape> = {}): PosterShape => ({
  tag: 'circle',
  attrs: { cx, cy, r, fill },
  ...options,
})
const polygon = (points: string, fill: string, options: Partial<PosterShape> = {}): PosterShape => ({
  tag: 'polygon',
  attrs: { points, fill },
  ...options,
})
const path = (d: string, fill: string, options: Partial<PosterShape> = {}): PosterShape => ({ tag: 'path', attrs: { d, fill }, ...options })
const outline = (shape: PosterShape, stroke: string, width = 8): PosterShape => ({
  ...shape,
  attrs: { ...shape.attrs, fill: 'none' },
  stroke,
  width: Math.max(3, width),
})
const rotated = (shapes: PosterShape[], degrees: number, x: number, y: number) =>
  shapes.map((shape) => ({ ...shape, rotate: [round(degrees), round(x), round(y)] as [number, number, number] }))

function getPalette(input: PosterInput): Palette {
  const base = KIND_COLOR[input.kind]
  const accent = INKS[hashText(`${input.artSeed}|ink3`) % INKS.length]
  const balance = hashText(`${input.artSeed}|balance`) % 3
  const light = mix(base, '#ffffff', 0.46)
  const deep = mix(base, BACK, 0.44)

  return { light, deep, accent, balance, hero: [deep, base, light][balance] }
}

function getComposition(
  input: PosterInput,
  template: number,
  random: () => number,
  palette: Palette,
): { field: PosterShape[]; hero: Placement; support: Placement[] } {
  const jitter = () => round((random() - 0.5) * 18)
  const scale = () => 0.91 + random() * 0.18
  const turn = () => round((random() - 0.5) * (input.kind === 'gate' ? 9 : 18))

  switch (template) {
    case 0:
      return {
        field: [rect(0, 0, 70, 160, mix(palette.deep, BACK, 0.7))],
        hero: [181 + jitter(), 76 + jitter(), 178 * scale(), turn()],
        support: [[48, 130, 62, 0]],
      }
    case 1:
      return {
        field: [rect(0, 99, 256, 61, mix(palette.deep, BACK, 0.5))],
        hero: [80 + jitter(), 76 + jitter(), 162 * scale(), turn()],
        support: [[217, 114, 74, 0]],
      }
    case 2:
      return {
        field: [polygon('0,0 108,0 0,116', mix(palette.deep, BACK, 0.65))],
        hero: [41 + jitter(), 103 + jitter(), 158 * scale(), turn()],
        support: [
          [145, 59, 83, turn()],
          [223, 20, 48, turn()],
        ],
      }
    case 3:
      return {
        field: [rect(0, 0, 76, 160, mix(palette.deep, BACK, 0.65))],
        hero: [181 + jitter(), 77 + jitter(), 156 * scale(), turn()],
        support: [
          [39, 41, 55, 0],
          [39, 106, 55, 0],
        ],
      }
    case 4:
      return {
        field: [outline(circle(128, 78, 111, 'none'), mix(palette.deep, BACK, 0.35), 11)],
        hero: [130 + jitter(), 78 + jitter(), 146 * scale(), turn()],
        support: [[236, 35, 54, 0]],
      }
    default:
      return {
        field: [polygon('188,0 256,0 256,160 229,160', mix(palette.deep, BACK, 0.58))],
        hero: [126 + jitter(), 70 + jitter(), 161 * scale(), turn()],
        support: [
          [212, 122, 77, turn()],
          [42, 20, 58, turn()],
        ],
      }
  }
}

function getKindForms(kind: CardView['kind'], x: number, y: number, size: number, palette: Palette, fill: string, rotation: number): PosterShape[] {
  const s = size
  const forms: PosterShape[] = []

  if (kind === 'step') {
    forms.push(rect(x - s * 0.52, y - s * 0.5, s * 0.9, s * 0.9, fill))
    forms.push(rect(x - s * 0.29, y - s * 0.29, s * 0.56, s * 0.56, palette.deep, { alpha: 0.72, blend: 'multiply' }))
    forms.push(rect(x + s * 0.11, y + s * 0.05, s * 0.47, s * 0.47, palette.accent, { alpha: 0.84, blend: 'screen' }))
  } else if (kind === 'pr') {
    forms.push(
      polygon(
        [
          point(x - s * 0.7, y - s * 0.67),
          point(x - s * 0.46, y - s * 0.67),
          point(x + s * 0.04, y - s * 0.13),
          point(x + s * 0.04, y + s * 0.17),
          point(x - s * 0.11, y + s * 0.17),
        ].join(' '),
        fill,
      ),
    )
    forms.push(
      polygon(
        [
          point(x - s * 0.7, y + s * 0.67),
          point(x - s * 0.46, y + s * 0.67),
          point(x + s * 0.04, y + s * 0.13),
          point(x + s * 0.04, y - s * 0.17),
          point(x - s * 0.11, y - s * 0.17),
        ].join(' '),
        fill,
      ),
    )
    forms.push(
      polygon(
        [
          point(x - s * 0.06, y - s * 0.18),
          point(x + s * 0.72, y - s * 0.18),
          point(x + s * 0.72, y + s * 0.18),
          point(x - s * 0.06, y + s * 0.18),
        ].join(' '),
        palette.accent,
        { alpha: 0.9, blend: 'screen' },
      ),
    )
  } else if (kind === 'placeholder') {
    forms.push(outline(rect(x - s * 0.53, y - s * 0.46, s * 1.06, s * 0.92, 'none'), fill, Math.max(8, s * 0.105)))
    forms.push(outline(circle(x + s * 0.14, y - s * 0.06, s * 0.31, 'none'), palette.accent, Math.max(7, s * 0.08)))

    for (let index = -1; index <= 0; index++)
      forms.push(
        path(`M${round(x - s * 0.36 + index * s * 0.22)} ${round(y + s * 0.35)}l${round(s * 0.34)} ${round(-s * 0.7)}`, 'none', {
          stroke: palette.light,
          width: Math.max(5, s * 0.07),
          alpha: 0.34,
        }),
      )
  } else if (kind === 'gate') {
    const arch = (width: number, height: number) =>
      `M${round(x - width / 2)} ${round(y + height * 0.5)}V${round(y - height * 0.06)}A${round(width / 2)} ${round(height * 0.48)} 0 0 1 ${round(x + width / 2)} ${round(y - height * 0.06)}V${round(y + height * 0.5)}Z`

    forms.push(path(arch(s * 1.02, s), fill))
    forms.push(path(arch(s * 0.68, s * 0.76), palette.deep, { alpha: 0.82, blend: 'multiply' }))
    forms.push(path(arch(s * 0.37, s * 0.57), palette.accent, { alpha: 0.83, blend: 'screen' }))
  } else {
    const band = (offset: number, width: number) =>
      `M${round(x - s * 0.74)} ${round(y - s * 0.24 + offset)}C${round(x - s * 0.34)} ${round(y - s * 0.95 + offset)} ${round(x + s * 0.01)} ${round(y + s * 0.74 + offset)} ${round(x + s * 0.75)} ${round(y - s * 0.36 + offset)}L${round(x + s * 0.75)} ${round(y - s * 0.36 + offset + width)}C${round(x + s * 0.01)} ${round(y + s * 0.74 + offset + width)} ${round(x - s * 0.34)} ${round(y - s * 0.95 + offset + width)} ${round(x - s * 0.74)} ${round(y - s * 0.24 + offset + width)}Z`

    forms.push(path(band(0, s * 0.3), fill))
    forms.push(path(band(s * 0.36, s * 0.15), palette.accent, { alpha: 0.82, blend: 'screen' }))
  }

  return rotated(forms, rotation, x, y)
}

function getSupportingForm(kind: CardView['kind'], x: number, y: number, size: number, palette: Palette, angle: number): PosterShape[] {
  const s = size
  let form: PosterShape

  if (kind === 'step') form = rect(x - s * 0.5, y - s * 0.5, s, s, palette.accent, { alpha: 0.82 })
  else if (kind === 'pr')
    form = polygon(
      [
        point(x - s * 0.55, y - s * 0.48),
        point(x - s * 0.1, y - s * 0.48),
        point(x + s * 0.55, y),
        point(x - s * 0.1, y + s * 0.48),
        point(x - s * 0.55, y + s * 0.48),
        point(x + s * 0.07, y),
      ].join(' '),
      palette.accent,
      { alpha: 0.88 },
    )
  else if (kind === 'placeholder') form = outline(rect(x - s * 0.5, y - s * 0.5, s, s, 'none'), palette.accent, Math.max(6, s * 0.12))
  else if (kind === 'gate')
    form = path(
      `M${round(x - s * 0.5)} ${round(y + s * 0.45)}V${round(y)}A${round(s * 0.5)} ${round(s * 0.5)} 0 0 1 ${round(x + s * 0.5)} ${round(y)}V${round(y + s * 0.45)}Z`,
      palette.accent,
      { alpha: 0.82 },
    )
  else
    form = path(
      `M${round(x - s * 0.6)} ${round(y)}Q${round(x)} ${round(y - s * 0.75)} ${round(x + s * 0.6)} ${round(y)}L${round(x + s * 0.6)} ${round(y + s * 0.27)}Q${round(x)} ${round(y - s * 0.48)} ${round(x - s * 0.6)} ${round(y + s * 0.27)}Z`,
      palette.accent,
      { alpha: 0.85 },
    )

  return rotated([form], angle, x, y)
}

function getStatusTreatment(status: CardView['status'], [x, y, s, turn]: Placement, palette: Palette): PosterShape[] {
  const extra: PosterShape[] = []

  if (status === 'review') {
    extra.push(outline(circle(x, y, s * 0.58, 'none'), palette.light, 7))
    extra.push(outline(circle(x, y, s * 0.66, 'none'), palette.accent, 4))
  }

  if (status === 'blocked')
    extra.push(
      polygon(
        [
          point(x - s * 0.64, y + s * 0.54),
          point(x - s * 0.54, y + s * 0.64),
          point(x + s * 0.64, y - s * 0.54),
          point(x + s * 0.54, y - s * 0.64),
        ].join(' '),
        BACK,
      ),
    )

  if (status === 'deferred')
    extra.push(
      rect(x - s * 0.19, y - s * 0.32, s * 0.12, s * 0.64, palette.light),
      rect(x + s * 0.07, y - s * 0.32, s * 0.12, s * 0.64, palette.light),
    )

  if (status === 'active')
    extra.push(
      polygon([point(x, y - s * 0.52), point(x + s * 0.52, y), point(x, y + s * 0.52)].join(' '), palette.accent, { alpha: 0.46, blend: 'screen' }),
    )

  if (status === 'ready') extra.push(outline(circle(x, y, s * 0.34, 'none'), palette.light, 8))

  return rotated(extra, turn, x, y)
}

export function getPosterSpec(input: PosterInput, forcedTemplate?: number): PosterSpec {
  const random = randomFor(input.artSeed)
  const palette = getPalette(input)
  const template = forcedTemplate ?? hashText(`${input.artSeed}|poster`) % 6
  const { field, hero, support } = getComposition(input, template, random, palette)
  const shapes = [rect(0, 0, 256, 160, palette.balance === 2 ? mix(palette.deep, BACK, 0.72) : BACK), ...field]
  const [heroX, heroY, heroSize, rotation] = hero

  for (let index = 0; index < Math.min(Math.max(input.leverage, 0), 6); index++) {
    const y = 23 + index * 21
    const from = Math.min(223, heroX + heroSize * 0.24)

    shapes.push(
      polygon(
        [point(from, heroY - 7 + index * 2), point(256, y - 7), point(256, y + 8), point(from, heroY + 8 + index * 2)].join(' '),
        palette.accent,
        { alpha: 0.4 },
      ),
    )
  }

  for (const [x, y, size, angle] of support) shapes.push(...getSupportingForm(input.kind, x, y, size, palette, angle))

  const heroFill = input.status === 'deferred' ? mix(palette.hero, BACK, 0.48) : input.status === 'ready' ? palette.deep : palette.hero

  shapes.push(...getKindForms(input.kind, heroX, heroY, heroSize, palette, heroFill, rotation))
  shapes.push(...getStatusTreatment(input.status, hero, palette))
  shapes.push(rect(0, 138, 256, 22, mix(palette.deep, BACK, 0.29), { alpha: 0.96 }))
  const visible = Math.min(Math.max(input.upstream, 0), 12)

  for (let index = 0; index < visible; index++) {
    const x = 8 + index * 20
    const tone = index % 2 === 0 ? palette.hero : palette.light

    if (input.kind === 'placeholder') shapes.push(outline(rect(x, 144, 13, 10, 'none'), tone, 3))
    else if (input.kind === 'gate') shapes.push(path(`M${x} 154v-4a6.5 6.5 0 0 1 13 0v4Z`, tone))
    else if (input.kind === 'note') shapes.push(polygon(`${x},154 ${x + 5},144 ${x + 13},144 ${x + 8},154`, tone))
    else if (input.kind === 'pr') shapes.push(polygon(`${x},144 ${x + 8},144 ${x + 13},149 ${x + 8},154 ${x},154 ${x + 5},149`, tone))
    else shapes.push(rect(x, 144, 13, 10, tone))
  }

  return { template, shapes, excessUpstream: Math.max(0, input.upstream - 12) }
}
