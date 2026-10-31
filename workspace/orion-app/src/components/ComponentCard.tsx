import type { CardView } from '../cardView'
import { SHAPE_LABEL, type ComponentShape } from '../model'
import { ShapeOutline } from './ShapeOutline'
import { SourceBadges } from './SourceBadges'

/** A part of a system diagram, drawn the same in every skin: its shape's outline, name, and what it does. */
export function ComponentCard({
  view,
  shape,
  width,
  height,
}: {
  view: CardView
  shape: ComponentShape
  width: number
  height: number
}) {
  return (
    <>
      <ShapeOutline shape={shape} width={width} height={height} />
      <div className="meta">
        <span className="component-mark" title="Component: a part of the system, not work" />
        <span className="meta-tag" title={view.tag}>
          {view.repo ?? SHAPE_LABEL[shape]}
        </span>
      </div>
      <div className="label">{view.title || 'Untitled component'}</div>
      {view.note && (
        <div className="component-note" title={view.note}>
          {view.note}
        </div>
      )}
      <div className="card-actions">
        <SourceBadges sources={view.sources} />
      </div>
    </>
  )
}
