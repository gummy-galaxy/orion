import { TASK_HEIGHT, TASK_WIDTH } from './model'

export type Skin = {
  id: string
  label: string
  size: { width: number; height: number }
  /** A skin that still works but is slated for removal. Settings tags it. */
  deprecated?: boolean
}

/** The first skin is the default, for anyone who hasn't picked one or whose pick is unknown. */
export const SKINS = [
  { id: 'trading', label: 'Trading cards', size: { width: 198, height: 285 } },
  { id: 'classic', label: 'Classic', size: { width: TASK_WIDTH, height: TASK_HEIGHT }, deprecated: true },
  { id: 'plain', label: 'Plain', size: { width: TASK_WIDTH, height: TASK_HEIGHT }, deprecated: true },
] as const satisfies readonly Skin[]

export type SkinId = (typeof SKINS)[number]['id']

export function skinOf(id: string): (typeof SKINS)[number] {
  return SKINS.find((skin) => skin.id === id) ?? SKINS[0]
}
