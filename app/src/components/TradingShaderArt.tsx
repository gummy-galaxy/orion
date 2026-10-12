import { useMemo } from 'react'
import type { CardView } from '../cardView'
import { getCardArtSpec } from '../skins/artSpec'
import type { InkPair } from '../skins/frameColor'
import { useCardArt } from '../skins/useCardArt'
import { TradingLiveArt } from './TradingLiveArt'

/** How much of the art runs live: none, the top layer on hover, or both layers in a peek or the details view. */
export type ArtMotion = 'still' | 'top' | 'all'

const TOP_SPEED = 0.6
const BASE_SPEED = 0.2

/**
 * A card's art from Paper Shaders: two dithered inks over a dark gradient, seeded by the card. The kind picks the
 * shapes: pull requests flow, steps wave, expected pull requests are sparse dots, and gates are planets.
 */
export function TradingShaderArt({
  kind,
  seed,
  inks,
  motion,
}: {
  kind: Exclude<CardView['kind'], 'note'>
  seed: string
  inks: InkPair
  motion: ArtMotion
}) {
  const [firstInk, secondInk] = inks
  const spec = useMemo(() => getCardArtSpec(seed, kind, [firstInk, secondInk]), [seed, kind, firstInk, secondInk])
  const full = useCardArt(seed, kind, inks)
  // Painted up front, so the live top layer can take over on hover without the still's own top showing through.
  const base = useCardArt(seed, kind, inks, false)
  const still = motion === 'still' ? full : (base ?? full)
  const back = `linear-gradient(${spec.angle}rad, ${spec.back[0]}, ${spec.back[1]})`

  return (
    <div className="trading-shader-art" style={{ background: back }}>
      {motion !== 'all' && still && <img src={still} alt="" />}
      {motion === 'all' && <TradingLiveArt layer={spec.base} speed={BASE_SPEED} />}
      {motion !== 'still' && <TradingLiveArt layer={spec.top} speed={TOP_SPEED} />}
    </div>
  )
}
