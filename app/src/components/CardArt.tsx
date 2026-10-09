import type { SourceRef } from '../derive'
import { CardArtTile } from './CardArtTile'
import { CardGrainArt } from './CardGrainArt'

const ART_TILES = 3

/** The art box: a panel for each source, side by side, or generated art alone when the card has none. */
export function CardArt({ id, sources, tone }: { id: string; sources: SourceRef[]; tone: string }) {
  const shown = sources.slice(0, ART_TILES)

  return (
    <div className={`art art-${Math.max(1, shown.length)}`}>
      {shown.length ? (
        shown.map((source, index) => (
          <CardArtTile
            key={source.domain + source.label}
            source={source}
            seed={id}
            tone={tone}
            more={index === shown.length - 1 ? sources.length - shown.length : 0}
          />
        ))
      ) : (
        <div className="art-tile">
          <CardGrainArt seed={id} tone={tone} palette={null} />
        </div>
      )}
    </div>
  )
}
