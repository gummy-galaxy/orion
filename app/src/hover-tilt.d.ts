import type { DetailedHTMLProps, HTMLAttributes } from 'react'

declare module 'react' {
  namespace JSX {
    interface IntrinsicElements {
      'hover-tilt': DetailedHTMLProps<HTMLAttributes<HTMLElement>, HTMLElement> & {
        'tilt-factor'?: number
        'scale-factor'?: number
        'exit-delay'?: number
        'glare-intensity'?: number
        shadow?: boolean
      }
    }
  }
}
