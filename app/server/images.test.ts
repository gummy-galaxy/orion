import { afterEach, describe, expect, it } from 'vitest'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { addImageAsset, readImageAsset } from './images.js'

const folders: string[] = []
afterEach(() => {
  for (const folder of folders.splice(0)) rmSync(folder, { recursive: true, force: true })
})

describe('image assets', () => {
  it('keeps binary image data outside the canvas and rejects unsafe names', () => {
    const folder = mkdtempSync(join(tmpdir(), 'orion-image-'))
    folders.push(folder)
    const bytes = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3])
    const added = addImageAsset(folder, bytes)
    expect(added.mime).toBe('image/png')
    expect(readImageAsset(folder, added.asset).bytes).toEqual(bytes)
    expect(() => readImageAsset(folder, '../orion.json')).toThrow('Invalid image asset')
    expect(() => addImageAsset(folder, Buffer.from('not an image'))).toThrow('Image must be PNG')
  })
})
