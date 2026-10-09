import { githubPath, usePalette } from '../cardMedia'
import type { SourceRef } from '../derive'
import { CardGrainArt } from './CardGrainArt'
import { Favicon } from './Favicon'

/** One source's panel in a card's art box: art in its colors, and its owner's avatar or its site's icon. */
export function CardArtTile({ source, seed, tone, more }: { source: SourceRef; seed: string; tone: string; more: number }) {
  const palette = usePalette(source)
  const owner = githubPath(source)?.split('/')[0]

  return (
    <div className="art-tile">
      {palette !== undefined && <CardGrainArt seed={seed + source.label} tone={tone} palette={palette} />}
      <span className="art-emblem">
        {owner ? (
          <img className="art-avatar" src={`https://github.com/${owner}.png?size=64`} alt="" draggable={false} />
        ) : (
          <Favicon domain={source.domain} />
        )}
        <span>{source.label}</span>
      </span>
      {more > 0 && <span className="art-more">+{more}</span>}
    </div>
  )
}
