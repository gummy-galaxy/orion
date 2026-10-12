import { ShaderMount, ditheringFragmentShader } from '@paper-design/shaders'
import { useEffect, useRef } from 'react'
import type { ArtLayer } from '../skins/artSpec'

/**
 * One layer of a card's art as a running shader. Browsers allow only a few WebGL contexts, so mount this only
 * where one card is in view at a time, such as the hovered card, a peek, or the details view.
 */
export function TradingLiveArt({ layer, speed }: { layer: ArtLayer; speed: number }) {
  const hostRef = useRef<HTMLDivElement>(null)
  const mountRef = useRef<ShaderMount | null>(null)

  useEffect(() => {
    const host = hostRef.current

    if (!host) return

    const { frame, ...uniforms } = layer
    let mount: ShaderMount

    try {
      mount = new ShaderMount(host, ditheringFragmentShader, uniforms, { premultipliedAlpha: true }, 0, frame, 2)
    } catch {
      return
    }

    mountRef.current = mount

    return () => {
      mount.dispose()
      mountRef.current = null
    }
  }, [layer])

  useEffect(() => {
    mountRef.current?.setSpeed(speed)
  }, [speed, layer])

  return <div ref={hostRef} className="trading-live-art" aria-hidden="true" />
}
