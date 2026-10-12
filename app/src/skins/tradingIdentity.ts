import { createContext } from 'react'

/**
 * How a trading card shows its kind, kept switchable while the options are compared:
 * - `tile`: the kind icon on a tile over the art.
 * - `emblem`: the kind drawn into the art, with a small mark beside the title.
 * - `frame`: the emblem inside the vibrant study's rim, lit by status and the art's inks.
 * - `shape`: the frame, with an outline cut by kind.
 * - `scene`: a grain-dithered sky scene picked by kind, display type, bare numbers, and a finish by rarity.
 * - `shader`: the scene card with #159's Paper Shaders art in place of the sky scene.
 * - `cosmos`: the scene's subject over Paper Shaders art.
 */
export type TradingIdentity = 'tile' | 'emblem' | 'frame' | 'shape' | 'scene' | 'shader' | 'cosmos'

/** Identities that share the scene card's type, numbers, shapes, and finish. */
export const SCENE_LOOKS: TradingIdentity[] = ['scene', 'shader', 'cosmos']

/** When shader art runs: the top layer while the card is hovered, or all of it, as in a peek or the details view. */
export type TradingMotion = 'hover' | 'always'

/** Which end of the caption row holds the rarity seal. */
export type SealSide = 'left' | 'right'

export const TRADING_IDENTITIES: TradingIdentity[] = ['tile', 'emblem', 'frame', 'shape', 'scene', 'shader', 'cosmos']

export const TradingIdentityContext = createContext<{ identity: TradingIdentity; sealSide: SealSide; motion?: TradingMotion }>({
  identity: 'scene',
  sealSide: 'right',
})
