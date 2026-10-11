import { createContext } from 'react'

/**
 * How a trading card shows its kind, kept switchable while the options are compared:
 * - `tile`: the kind icon on a tile over the art.
 * - `emblem`: the kind drawn into the art, with a small mark beside the title.
 * - `frame`: the emblem inside the vibrant study's rim, lit by status and the art's inks.
 * - `shape`: the frame, with an outline cut by kind.
 */
export type TradingIdentity = 'tile' | 'emblem' | 'frame' | 'shape'

/** Which end of the caption row holds the rarity seal. */
export type SealSide = 'left' | 'right'

export const TRADING_IDENTITIES: TradingIdentity[] = ['tile', 'emblem', 'frame', 'shape']

export const TradingIdentityContext = createContext<{ identity: TradingIdentity; sealSide: SealSide }>({
  identity: 'emblem',
  sealSide: 'right',
})
