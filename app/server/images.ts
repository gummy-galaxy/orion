import { randomUUID } from 'node:crypto'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

export const MAX_IMAGE_BYTES = 5 * 1024 * 1024

export function imageFormat(bytes: Uint8Array): { extension: string; mime: string } {
  const head = Buffer.from(bytes.subarray(0, 12))
  if (head.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return { extension: 'png', mime: 'image/png' }
  if (head[0] === 255 && head[1] === 216 && head[2] === 255) return { extension: 'jpg', mime: 'image/jpeg' }
  if (head.toString('ascii', 0, 6) === 'GIF87a' || head.toString('ascii', 0, 6) === 'GIF89a') return { extension: 'gif', mime: 'image/gif' }
  if (head.toString('ascii', 0, 4) === 'RIFF' && head.toString('ascii', 8, 12) === 'WEBP') return { extension: 'webp', mime: 'image/webp' }
  throw new Error('Image must be PNG, JPEG, GIF, or WebP')
}

export function addImageAsset(dir: string, bytes: Uint8Array) {
  if (!bytes.length || bytes.length > MAX_IMAGE_BYTES) throw new Error('Image must be 5 MB or smaller')
  const { extension, mime } = imageFormat(bytes)
  const asset = `${randomUUID()}.${extension}`
  const folder = join(dir, 'assets')
  mkdirSync(folder, { recursive: true })
  writeFileSync(join(folder, asset), bytes, { flag: 'wx' })
  return { asset, mime }
}

export function readImageAsset(dir: string, asset: string) {
  if (!/^[a-z0-9-]+\.(png|jpg|gif|webp)$/.test(asset)) throw new Error('Invalid image asset')
  const bytes = readFileSync(join(dir, 'assets', asset))
  if (bytes.length > MAX_IMAGE_BYTES || imageFormat(bytes).extension !== asset.split('.').at(-1)) throw new Error('Invalid image asset')
  return { bytes, mime: imageFormat(bytes).mime }
}
