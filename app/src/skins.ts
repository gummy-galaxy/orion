import { TASK_HEIGHT, TASK_WIDTH } from './model'

export type Skin = { id: string; label: string; size: { width: number; height: number } }

export const SKINS = [
  { id: 'classic', label: 'Classic', size: { width: TASK_WIDTH, height: TASK_HEIGHT } },
  { id: 'plain', label: 'Plain', size: { width: TASK_WIDTH, height: TASK_HEIGHT } },
  { id: 'trading', label: 'Trading cards', size: { width: 288, height: 400 } },
] as const satisfies readonly Skin[]

export type SkinId = (typeof SKINS)[number]['id']

export function skinOf(id: string): (typeof SKINS)[number] {
  return SKINS.find((skin) => skin.id === id) ?? SKINS[0]
}
