import { useState } from 'react'
import { importImage } from '../persist'
import { TOKENS } from '../tokens'
import { isAssetId, type CanvasStyle, type StyleChange } from '../style'
import { CoverImage } from './CoverImage'

const COLOR_TOKENS = TOKENS.filter((token) => token.group === 'color')
const IMAGE_TYPES = 'image/png,image/jpeg,image/gif,image/webp'
const DEFAULT_CUSTOM_COLOR = '#1d1b2e'

/** Picks a color token, a custom color, or an image for a cover and background. Reset returns to stock. */
export function CoverSettings({
  title,
  workspace,
  current,
  change,
}: {
  title: string
  workspace: string
  current: CanvasStyle
  change: (change: StyleChange) => void
}) {
  const [error, setError] = useState<string | null>(null)
  const background = current.background
  const hasImageBackground = isAssetId(background)
  const customColor = background?.startsWith('#') ? background : undefined
  const tokenName = COLOR_TOKENS.some((token) => token.name === background) ? background : undefined
  const selected = hasImageBackground ? 'image' : customColor ? 'custom' : (tokenName ?? '')

  const pickImage = async (file: File | undefined, field: 'cover' | 'background') => {
    if (!file) return

    setError(null)

    try {
      const { asset } = await importImage(file, workspace)

      change({ [field]: asset })
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'Could not add the image.')
    }
  }

  const chooseBackground = (value: string) => {
    if (value === 'custom') change({ background: customColor ?? DEFAULT_CUSTOM_COLOR })
    else if (value === '') change({ background: null })
    else if (value !== 'image') change({ background: value })
  }

  return (
    <section className="cover-settings" aria-label={title}>
      <h3>{title}</h3>
      <div className="cover-preview">
        {current.cover ? <CoverImage workspace={workspace} asset={current.cover} className="cover-preview-image" /> : <span>No cover</span>}
      </div>
      <div className="row">
        <label className="btn">
          Choose cover image
          <input
            type="file"
            accept={IMAGE_TYPES}
            className="cover-file"
            onChange={(event) => {
              void pickImage(event.target.files?.[0], 'cover')
              event.target.value = ''
            }}
          />
        </label>
        {current.cover && (
          <button type="button" className="btn" onClick={() => change({ cover: null })}>
            Remove cover
          </button>
        )}
      </div>
      <label htmlFor={`${title}-background`}>Background</label>
      <select id={`${title}-background`} value={selected} onChange={(event) => chooseBackground(event.target.value)}>
        <option value="">Stock</option>
        {COLOR_TOKENS.map((token) => (
          <option key={token.name} value={token.name}>
            {token.name}
          </option>
        ))}
        <option value="custom">Custom color</option>
        {hasImageBackground && <option value="image">Image</option>}
      </select>
      {selected === 'custom' && (
        <input
          type="color"
          aria-label="Custom background color"
          value={customColor?.length === 7 ? customColor : DEFAULT_CUSTOM_COLOR}
          onChange={(event) => change({ background: event.target.value })}
        />
      )}
      <div className="row">
        <label className="btn">
          Choose background image
          <input
            type="file"
            accept={IMAGE_TYPES}
            className="cover-file"
            onChange={(event) => {
              void pickImage(event.target.files?.[0], 'background')
              event.target.value = ''
            }}
          />
        </label>
        <button type="button" className="btn" onClick={() => change({ cover: null, background: null })}>
          Reset to stock
        </button>
      </div>
      {error && (
        <p className="cover-error" role="alert">
          {error}
        </p>
      )}
    </section>
  )
}
