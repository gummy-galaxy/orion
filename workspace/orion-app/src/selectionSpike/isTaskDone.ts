import { CARDS, MOVE_ZONE } from './board'
import { cardRect } from './cardRect'
import { rectsOverlap } from './rectsOverlap'
import type { Positions, Rect, TaskId } from './types'

type State = { selection: ReadonlySet<string>; positions: Positions; start: Positions; view: Rect }

const idsIn = (area: string) => CARDS.filter((card) => card.area === area).map((card) => card.id)

const sameSet = (a: ReadonlySet<string>, b: string[]) => a.size === b.length && b.every((id) => a.has(id))

const inside = (outer: Rect, inner: Rect) => inner.x0 >= outer.x0 && inner.y0 >= outer.y0 && inner.x1 <= outer.x1 && inner.y1 <= outer.y1

const unmoved = (state: State, ids: string[]) =>
  ids.every((id) => state.positions[id].x === state.start[id].x && state.positions[id].y === state.start[id].y)

/** Whether the board now meets the task's goal. */
export function isTaskDone(task: TaskId, state: State) {
  const all = Object.keys(state.positions)

  switch (task) {
    case 'isolate':
      return sameSet(state.selection, idsIn('launch'))
    case 'exclude':
      return sameSet(
        state.selection,
        idsIn('accounts').filter((id) => id !== 'sso'),
      )

    case 'move': {
      const launch = idsIn('launch')

      return (
        launch.every((id) => inside(MOVE_ZONE, cardRect(state.positions[id]))) &&
        unmoved(
          state,
          all.filter((id) => !launch.includes(id)),
        )
      )
    }

    case 'navigate':
      return idsIn('archive').every((id) => inside(state.view, cardRect(state.positions[id])))

    case 'pile': {
      const pile = idsIn('new')

      return (
        unmoved(
          state,
          all.filter((id) => !pile.includes(id)),
        ) && pile.every((id) => all.every((other) => other === id || !rectsOverlap(cardRect(state.positions[id]), cardRect(state.positions[other]))))
      )
    }
  }
}
