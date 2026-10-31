import { getFolderName } from '../sessions/getFolderName'
import type { StartOptions } from '../sessions/types'

/** Where the session would start, and whether it will show on the card. */
export function StartPlace({ options }: { options: StartOptions }) {
  const folder = <b title={options.folder ?? undefined}>{getFolderName(options.folder)}</b>
  const tracking = options.attaches ? null : <> Add a {options.agent} source to see it on this card.</>

  if (options.place === 'checkout') {
    return (
      <>
        Opens {options.agent} in {folder}.{tracking}
      </>
    )
  }

  if (options.place === 'clone') {
    return (
      <>
        Opens {options.agent} in {folder} to make a worktree for {options.branch ?? 'a new branch'}.{tracking}
      </>
    )
  }

  return (
    <>
      Opens {options.agent}, which asks where to work.{tracking}
    </>
  )
}
