import type { CardView } from '../cardView'
import { getCardArt } from '../skins/cardArt'
import type { InkPair } from '../skins/frameColor'
import { useCardArt } from '../skins/useCardArt'

type ArtKind = Exclude<CardView['kind'], 'note'>

export function TradingArtwork({ view, kind, inks }: { view: CardView; kind: ArtKind; inks: InkPair }) {
  const image = useCardArt(view.artSeed, kind, inks)
  const fallback = getCardArt(view.artSeed, kind)

  return (
    <div className="trading-art">
      {image ? (
        <img src={image} alt="" />
      ) : (
        <svg viewBox="0 0 128 96" preserveAspectRatio="xMidYMid slice" aria-hidden="true" dangerouslySetInnerHTML={{ __html: fallback.markup }} />
      )}
      <i className="trading-holo" aria-hidden="true" />
      {view.status === 'done' && <span className="trading-stamp">{kind === 'pr' ? 'Merged' : 'Done'}</span>}
    </div>
  )
}
