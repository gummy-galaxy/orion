import { ShaderMount, ditheringFragmentShader } from '@paper-design/shaders'
import type { CardArtSpec } from './artSpec'

type Painter = { canvas: HTMLCanvasElement; paint: (spec: CardArtSpec) => string }
const PAINTER_COUNT = 2
let painters: Painter[] | null = null
let nextPainter = 0

function createPainter(): Painter {
  const host = document.createElement('div')

  host.style.cssText = 'position:fixed;left:0;top:0;width:260px;height:156px;visibility:hidden;pointer-events:none;z-index:-1'
  document.body.append(host)

  const initial = {
    u_colorBack: [0, 0, 0, 0],
    u_colorFront: [1, 1, 1, 1],
    u_shape: 2,
    u_type: 3,
    u_pxSize: 2,
    u_fit: 0,
    u_scale: 1,
    u_rotation: 0,
    u_offsetX: 0,
    u_offsetY: 0,
    u_originX: 0.5,
    u_originY: 0.5,
    u_worldWidth: 0,
    u_worldHeight: 0,
  }
  let mount: ShaderMount

  try {
    mount = new ShaderMount(host, ditheringFragmentShader, initial, { preserveDrawingBuffer: true, premultipliedAlpha: true }, 0, 0, 2)
  } catch (error) {
    host.remove()
    throw error
  }

  function drawLayer(context: CanvasRenderingContext2D, layer: CardArtSpec['base']) {
    const { frame, ...uniforms } = layer

    mount.setUniforms(uniforms)
    mount.setFrame(frame)
    context.drawImage(mount.canvasElement, 0, 0, context.canvas.width, context.canvas.height)
  }

  return {
    canvas: mount.canvasElement,
    paint(spec) {
      const canvas = document.createElement('canvas')

      canvas.width = 260
      canvas.height = 156
      const context = canvas.getContext('2d')

      if (!context) throw new Error('Canvas 2D is unavailable')

      const radius = Math.max(canvas.width, canvas.height)
      const gradient = context.createLinearGradient(
        canvas.width / 2 - (Math.cos(spec.angle) * radius) / 2,
        canvas.height / 2 - (Math.sin(spec.angle) * radius) / 2,
        canvas.width / 2 + (Math.cos(spec.angle) * radius) / 2,
        canvas.height / 2 + (Math.sin(spec.angle) * radius) / 2,
      )

      gradient.addColorStop(0, spec.back[0])
      gradient.addColorStop(1, spec.back[1])
      context.fillStyle = gradient
      context.fillRect(0, 0, canvas.width, canvas.height)
      drawLayer(context, spec.base)
      drawLayer(context, spec.top)

      return canvas.toDataURL('image/png')
    },
  }
}

export async function paintCardArt(spec: CardArtSpec): Promise<string> {
  if (typeof document === 'undefined' || typeof WebGLRenderingContext === 'undefined') throw new Error('WebGL is unavailable')

  if (!painters) painters = Array.from({ length: PAINTER_COUNT }, createPainter)

  const painter = painters[nextPainter++ % painters.length]

  for (let frame = 0; frame < 90 && painter.canvas.width === 300; frame++) {
    await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()))
  }

  if (painter.canvas.width === 300) throw new Error('Shader canvas did not size')

  return painter.paint(spec)
}
