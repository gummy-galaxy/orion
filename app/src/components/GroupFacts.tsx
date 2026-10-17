import type { GroupStats } from '../derive'

/** A group's progress. Groups that hold no work, like the boundaries of a system diagram, have none to show. */
export function GroupFacts({ stats }: { stats?: GroupStats }) {
  if (!stats?.total) return null

  return (
    <p className="facts">
      {stats.done}/{stats.total} done · {stats.ready} ready · {stats.blocked} blocked
      {stats.outside > 0 && <> · unblocks {stats.outside}</>}
    </p>
  )
}
