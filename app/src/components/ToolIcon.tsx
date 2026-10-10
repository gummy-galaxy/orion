/** An 18px line icon drawn from one SVG path, for toolbar buttons. */
export function ToolIcon({ path }: { path: string }) {
  return (
    <svg viewBox="0 0 20 20" width="18" height="18" aria-hidden="true">
      <path d={path} fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  )
}
