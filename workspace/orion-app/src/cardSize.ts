import { atom } from 'jotai'
import { skinOf } from './skins'
import { skinAtom } from './state'

export type CardSize = { width: number; height: number }

export const cardSizeAtom = atom((get) => skinOf(get(skinAtom)).size)
