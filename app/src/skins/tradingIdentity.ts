import { createContext } from 'react'

/**
 * How a trading card shows its kind, kept switchable while the options are compared:
 * - `tile`: the kind icon on a tile over the art.
 * - `emblem`: the kind drawn into the art, with a small mark beside the title.
 * - `frame`: the emblem inside the vibrant study's rim, lit by status and the art's inks.
 * - `shape`: the frame, with an outline cut by kind.
 * - `scene`: a grain-dithered sky scene picked by kind, display type, bare numbers, and a finish by rarity.
 */
export type TradingIdentity = 'tile' | 'emblem' | 'frame' | 'shape' | 'scene'

/** Which end of the caption row holds the rarity seal. */
export type SealSide = 'left' | 'right'

export const TRADING_IDENTITIES: TradingIdentity[] = ['tile', 'emblem', 'frame', 'shape', 'scene']

export const TradingIdentityContext = createContext<{ identity: TradingIdentity; sealSide: SealSide }>({
  identity: 'scene',
  sealSide: 'right',
})
