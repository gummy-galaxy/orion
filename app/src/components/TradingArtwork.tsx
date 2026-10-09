import { createElement, useEffect, useMemo, useRef, useState } from 'react'
import type { CardView } from '../cardView'
import { getCachedPoster, requestPoster } from '../skins/posterPainter'
import { getPosterSpec } from '../skins/posterSpec'

type ArtKind = CardView['kind']

type PosterSize = { width: number; height: number }

export function TradingArtwork({ view, kind, status }: { view: CardView; kind: ArtKind; status: { label: string; className: string } }) {
  const artRef = useRef<HTMLDivElement>(null)
  const [size, setSize] = useState<PosterSize | null>(null)
  const [painted, setPainted] = useState<{ key: string; image: string } | null>(null)
  const input = useMemo(
    () => ({ artSeed: view.artSeed, kind, status: view.status, upstream: view.upstream, leverage: view.leverage }),
    [view.artSeed, kind, view.status, view.upstream, view.leverage],
  )
  const spec = useMemo(() => getPosterSpec(input), [input])
  const key = size && JSON.stringify([input.artSeed, input.kind, input.status, input.upstream, input.leverage, size.width, size.height])
  const image = size ? (getCachedPoster(input, size.width, size.height) ?? (painted?.key === key ? painted.image : null)) : null
  const repositoryName = view.repo?.split('/').at(-1)

  useEffect(() => {
    const element = artRef.current

    if (!element) return

    const measure = () => {
      const bounds = element.getBoundingClientRect()

      if (!bounds.width || !bounds.height) return

      const ratio = window.devicePixelRatio || 1
      const width = Math.max(1, Math.round(bounds.width * ratio))
      const height = Math.max(1, Math.round(bounds.height * ratio))

      setSize((current) => (current?.width === width && current.height === height ? current : { width, height }))
    }

    measure()
    const observer = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(measure)

    observer?.observe(element)
    window.addEventListener('resize', measure)

    return () => {
      observer?.disconnect()
      window.removeEventListener('resize', measure)
    }
  }, [])

  useEffect(() => {
    if (!size || !key) return

    return requestPoster(input, size.width, size.height, (nextImage) => {
      if (nextImage) setPainted({ key, image: nextImage })
    })
  }, [input, size, key])

  return (
    <div className="trading-art" ref={artRef}>
      {image ? (
        <img src={image} alt="" />
      ) : (
        <svg viewBox="0 0 256 160" preserveAspectRatio="none" aria-hidden="true">
          {spec.shapes.map((shape, index) =>
            createElement(shape.tag, {
              key: index,
              ...shape.attrs,
              stroke: shape.stroke,
              strokeWidth: shape.width,
              opacity: shape.alpha,
              transform: shape.rotate ? `rotate(${shape.rotate.join(' ')})` : undefined,
              style: shape.blend ? { mixBlendMode: shape.blend } : undefined,
            }),
          )}
        </svg>
      )}
      {spec.excessUpstream > 0 && <span className="trading-art-count">+{spec.excessUpstream}</span>}
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
