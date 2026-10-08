export function Ring({ done, total, size = 22 }: { done: number; total: number; size?: number }) {
  const radius = 8
  const circumference = 2 * Math.PI * radius
  return (
    <svg viewBox="0 0 20 20" width={size} height={size} className="ring" aria-hidden="true">
      <circle cx="10" cy="10" r={radius} className="ring-bg" />
      <circle
        cx="10"
        cy="10"
        r={radius}
        className="ring-fg"
        strokeDasharray={`${total ? (done / total) * circumference : 0} ${circumference}`}
        transform="rotate(-90 10 10)"
      />
    </svg>
  )
}
