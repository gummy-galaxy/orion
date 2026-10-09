/** A blocker's box. Its arrows meet at the middle; flames and the spiked crown rise out over the top. */
export const BLOCKER_WIDTH = 76
export const BLOCKER_HEIGHT = 76

/** A tongue of flame: a belly that bulges on one side and hooks over to the other at its tip. */
export const flame = (x: number, base: number, width: number, height: number, lean: number) =>
  `M${x - width / 2},${base}C${x - width * 0.6},${base - height * 0.35} ${x + lean - width * 0.25},${base - height * 0.6} ${x + lean},${base - height}` +
  `C${x + lean + width * 0.2},${base - height * 0.55} ${x + width * 0.6},${base - height * 0.3} ${x + width / 2},${base}Z`

export type Tongue = [x: number, base: number, width: number, height: number, seconds: number]

/** In the gate's own units, where the doorway's sill is at y 16 and the tallest spike tops out at y -28. */
export const PILLAR_FIRE: Tongue[] = [
  [-17.5, -15, 4, 12, 0.7],
  [-15, -15, 6, 21, 0.9],
  [-12.5, -15, 4, 14, 0.6],
  [-10.5, -15, 3, 8, 0.55],
  [10.5, -15, 3, 8, 0.5],
  [12.5, -15, 4, 13, 0.65],
  [15, -15, 6, 20, 0.85],
  [17.5, -15, 4, 11, 0.6],
]
export const DOOR_FIRE: Tongue[] = [
  [-5, 16, 4, 12, 0.6],
  [-2, 16, 5, 19, 0.8],
  [1.5, 16, 5, 17, 0.7],
  [4.8, 16, 4, 11, 0.55],
]
export const SILL_FIRE: Tongue[] = [
  [-19, 16.5, 5, 11, 0.6],
  [-16, 16.5, 5, 8, 0.5],
  [-12.5, 16.5, 5, 6, 0.55],
  [-8.5, 16.5, 4, 5, 0.5],
  [8.5, 16.5, 4, 5, 0.55],
  [12.5, 16.5, 5, 7, 0.5],
  [16, 16.5, 5, 9, 0.6],
  [19, 16.5, 5, 12, 0.65],
]
/** x, sideways drift, seconds to rise, and how far into the rise it starts. */
export const EMBERS: [number, number, number, number][] = [
  [-15, -2, 1.6, 0.1],
  [-13, 2, 2.1, 0.7],
  [-3, -2, 1.7, 1.2],
  [0, 2, 2.2, 0.4],
  [3, -2, 1.5, 0.9],
  [13, 2, 1.9, 0.2],
  [15, -2, 1.4, 1.0],
]
/** Molten seams in the stone, each glowing on its own slow beat. */
export const CRACKS: [d: string, seconds: number][] = [
  ['M-14.2,-9.5Q-13.6,-5 -14.6,-1T-14,8', 2.6],
  ['M14.1,-8Q14.7,-3 13.9,2T14.4,10', 3.1],
  ['M-12,-15.4Q-9,-13.6 -6,-14.8', 2.2],
  ['M6,-15.4Q9,-12.8 12,-14.2', 2.8],
  ['M-10.6,2Q-9.6,7 -10.3,12.5', 3.4],
]
/** The jagged crown along the lintel, tallest over the doorway. */
export const CROWN =
  'M-18,-16L-17,-19L-15.5,-16.8L-14,-21L-12.5,-17L-10.5,-19.5L-9,-17L-6.5,-22L-5,-17.5L-3,-24L-1.5,-18.5L0,-28' +
  'L1.5,-18.5L3,-24L5,-17.5L6.5,-22L9,-17L10.5,-19.5L12.5,-17L14,-21L15.5,-16.8L17,-19L18,-16Z'

/** Whether the viewer asked for less motion; the blocker then stands still. */
export const calm = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches
