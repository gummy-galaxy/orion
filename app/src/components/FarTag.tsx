import type { ReactNode } from 'react'

export function FarTag({ className, children }: { className: string; children: ReactNode }) {
  return (
    <div className="pop-place">
      <div className={`${className} far-card`}>{children}</div>
    </div>
  )
}
