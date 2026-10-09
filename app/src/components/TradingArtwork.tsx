import type { CardView } from '../cardView'
import { getCardArt } from '../skins/cardArt'
import type { InkPair } from '../skins/frameColor'
import { useCardArt } from '../skins/useCardArt'

type ArtKind = Exclude<CardView['kind'], 'note'>

export function TradingArtwork({
  view,
  kind,
  inks,
  status,
}: {
  view: CardView
  kind: ArtKind
  inks: InkPair
  status: { label: string; className: string }
}) {
  const image = useCardArt(view.artSeed, kind, inks)
  const fallback = getCardArt(view.artSeed, kind)
  const repositoryName = view.repo?.split('/').at(-1)

  return (
    <div className="trading-art">
      {image ? (
        <img src={image} alt="" />
      ) : (
        <svg viewBox="0 0 128 96" preserveAspectRatio="xMidYMid slice" aria-hidden="true" dangerouslySetInnerHTML={{ __html: fallback.markup }} />
      )}
      <i className="trading-holo" aria-hidden="true" />
      {view.status === 'done' ? (
        <span className="trading-stamp">{kind === 'pr' ? 'Merged' : 'Done'}</span>
      ) : (
        <span className="trading-art-status">{status.label}</span>
      )}
      {repositoryName && (
        <span className="trading-emblem">
          <i>{repositoryName[0].toUpperCase()}</i>
          {repositoryName}
        </span>
      )}
    </div>
  )
}
