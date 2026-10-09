import { useEffect, useState } from 'react'
import { bakeArt, type Hue } from '../art'

/** Generated art in the colors of its source, or of the card's status until it has some. */
export function CardGrainArt({ seed, tone, palette }: { seed: string; tone: string; palette: Hue[] | null }) {
  const [art, setArt] = useState<{ for: string; src: string } | null>(null)
  const inputs = `${tone}:${seed}:${JSON.stringify(palette)}`

  useEffect(() => {
    let live = true

    void bakeArt(seed, tone, palette).then((src) => live && setArt({ for: inputs, src }))

    return () => {
      live = false
    }
  }, [inputs, seed, tone, palette])

  return art?.for === inputs ? <img className="art-grain" src={art.src} alt="" draggable={false} /> : null
}
