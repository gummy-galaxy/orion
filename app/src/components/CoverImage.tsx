import { useEffect, useState } from 'react'
import { imageSource } from '../persist'

/** A canvas or group's cover or backdrop image, read from the workspace's assets. Renders nothing until it loads. */
export function CoverImage({ workspace, asset, className }: { workspace: string; asset: string; className: string }) {
  const [loaded, setLoaded] = useState<{ key: string; source: string } | null>(null)
  const key = `${workspace}/${asset}`
  const source = loaded?.key === key ? loaded.source : null

  useEffect(() => {
    let active = true
    let objectUrl: string | null = null

    void imageSource(workspace, asset)
      .then((next) => {
        objectUrl = next

        if (active) setLoaded({ key, source: next })
        else URL.revokeObjectURL(next)
      })
      .catch(() => active && setLoaded(null))

    return () => {
      active = false

      if (objectUrl) URL.revokeObjectURL(objectUrl)
    }
  }, [workspace, asset, key])

  return source ? <img className={className} src={source} alt="" draggable={false} /> : null
}
