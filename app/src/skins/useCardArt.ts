import { useEffect, useState } from 'react'
import type { CardView } from '../cardView'
import { getCardArtSpec } from './artSpec'
import { paintCardArt } from './cardArtPainter'
import type { InkPair } from './frameColor'

type ArtKind = Exclude<CardView['kind'], 'note'>
const artCache = new Map<string, Promise<string | null>>()

export function useCardArt(seed: string, kind: ArtKind, inks: InkPair, withTop = true): string | null {
  const [firstInk, secondInk] = inks
  const key = `${seed}\u0000${kind}\u0000${firstInk}\u0000${secondInk}\u0000${withTop}`
  const [image, setImage] = useState<{ key: string; url: string | null }>({ key, url: null })

  useEffect(() => {
    let isMounted = true
    let pending = artCache.get(key)

    if (!pending) {
      pending = paintCardArt(getCardArtSpec(seed, kind, [firstInk, secondInk]), withTop).catch(() => null)
      artCache.set(key, pending)
    }

    pending.then((url) => {
      if (isMounted) setImage({ key, url })
    })

    return () => {
      isMounted = false
    }
  }, [seed, kind, firstInk, secondInk, withTop, key])

  return image.key === key ? image.url : null
}
