import { memo, useEffect, useState } from 'react'
import type { NodeProps } from '@xyflow/react'
import type { ImageNode } from './model'
import { imageSource } from './persist'

export const ImageView = memo(function ImageView({ data }: NodeProps<ImageNode>) {
  const [loaded, setLoaded] = useState<{ key: string; source: string } | null>(null)
  const key = `${data.workspace}/${data.asset}`
  const source = loaded?.key === key ? loaded.source : null

  useEffect(() => {
    let active = true
    let objectUrl: string | null = null

    void imageSource(data.workspace, data.asset)
      .then((source) => {
        objectUrl = source

        if (active) setLoaded({ key, source })
        else URL.revokeObjectURL(source)
      })
      .catch(() => active && setLoaded(null))

    return () => {
      active = false

      if (objectUrl) URL.revokeObjectURL(objectUrl)
    }
  }, [data.workspace, data.asset, key])

  return (
    <div className="image-node" title={data.label}>
      {source ? <img src={source} alt={data.label} draggable={false} /> : <span className="image-missing">Image unavailable</span>}
      <span className="image-label">{data.label}</span>
    </div>
  )
})
