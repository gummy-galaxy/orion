import type { GroupStats } from '../derive'

export function GroupFacts({ stats }: { stats?: GroupStats }) {
  if (!stats) return null
  return (
    <p className="facts">
      {stats.done}/{stats.total} done · {stats.ready} ready · {stats.blocked} blocked
      {stats.outside > 0 && <> · unblocks {stats.outside}</>}
    </p>
  )
}
