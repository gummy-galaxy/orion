import { createContext } from 'react'
import type { Plug } from '../routing/types'

/** What a plug can ask of the spike: draw its links in full while it's hovered, and mark the card it jumped to. */
export type PlugActions = { reveal: (plug: Plug | null) => void; flash: (card: string) => void }

export const PlugContext = createContext<PlugActions>({ reveal: () => {}, flash: () => {} })
