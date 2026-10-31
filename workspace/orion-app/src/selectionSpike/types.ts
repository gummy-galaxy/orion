export type Point = { x: number; y: number }

export type Rect = { x0: number; y0: number; x1: number; y1: number }

export type Area = 'launch' | 'accounts' | 'docs' | 'archive' | 'loose' | 'new'

export type SpikeCard = { id: string; title: string; area: Area; x: number; y: number }

export type SpikeLink = { from: string; to: string }

export type Positions = Record<string, Point>

/** How a gesture's hits change the selection it started from. */
export type Combine = 'replace' | 'add' | 'subtract'

/** What a left drag on empty canvas does. */
export type LeftDrag = 'box' | 'sweep' | 'magnet' | 'gather'

/** What a right drag does: nothing, as today, or pan with a short click still opening the menu. */
export type RightDrag = 'menu' | 'pan'

/** Today's ⇧/⌘ add, or ⇧ add, ⌥ subtract, and ⌘ follow links. */
export type Modifiers = 'baseline' | 'full'

export type Gesture = { leftDrag: LeftDrag; rightDrag: RightDrag; modifiers: Modifiers }

export type Camera = { x: number; y: number; zoom: number }

export type TaskId = 'isolate' | 'exclude' | 'move' | 'navigate' | 'pile'
