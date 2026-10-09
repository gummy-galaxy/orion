import { useEffect, useState } from 'react'
import { paletteOf, type Hue } from './art'
import type { SourceRef } from './derive'

/** The repository, pull request, or issue a GitHub source points at, as `owner/repo[/pull/123]`. */
export function githubPath(source: SourceRef): string | null {
  if (source.domain !== 'github.com' || !source.href) return null

  const parts = new URL(source.href).pathname.split('/').filter(Boolean)
  const path = ['pull', 'issues'].includes(parts[2]) ? parts.slice(0, 4) : parts.slice(0, 2)

  return path.length >= 2 ? path.join('/') : null
}

const paletteCache = new Map<string, Promise<Hue[] | null>>()

function lookupPalette(path: string): Promise<Hue[] | null> {
  let found = paletteCache.get(path)

  if (!found) {
    found = fetch(`/api/media?path=${encodeURIComponent(path)}`)
      .then((response) => (response.ok ? (response.json() as Promise<{ src: string; video: boolean } | null>) : null))
      .then((media) => (media ? paletteOf(media.src, media.video) : null))
      .catch(() => null)
    paletteCache.set(path, found)
  }

  return found
}

/** The colors of a pull request's description media or GitHub's preview of it, once the dev server has found some. */
export function usePalette(source: SourceRef): Hue[] | null | undefined {
  const path = githubPath(source)
  const [palette, setPalette] = useState<{ path: string; palette: Hue[] | null } | null>(null)

  useEffect(() => {
    if (!path) return

    let live = true

    void lookupPalette(path).then((found) => live && setPalette({ path, palette: found }))

    return () => {
      live = false
    }
  }, [path])

  if (!path) return null

  return palette?.path === path ? palette.palette : undefined
}
