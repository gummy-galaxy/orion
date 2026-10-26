import { DESTINATIONS, PRESETS, TASKS } from '../selectionSpike/board'
import { presetOf } from '../selectionSpike/presetOf'
import type { Area, Gesture, LeftDrag, Modifiers, RightDrag, TaskId } from '../selectionSpike/types'

export type TaskRun = { task: TaskId; preset: string; startedAt: number; undos: number; cancels: number; seconds?: number }

type Props = {
  gesture: Gesture
  setGesture: (gesture: Gesture) => void
  run: TaskRun | null
  results: TaskRun[]
  now: number
  startTask: (task: TaskId) => void
  goTo: (area: Area) => void
  undo: () => void
  reset: () => void
}

const LEFT_DRAGS: { id: LeftDrag; label: string }[] = [
  { id: 'box', label: 'Box' },
  { id: 'sweep', label: 'Sweep' },
  { id: 'magnet', label: 'Magnet' },
  { id: 'gather', label: 'Gather' },
]

const RIGHT_DRAGS: { id: RightDrag; label: string }[] = [
  { id: 'menu', label: 'Menu only' },
  { id: 'pan', label: 'Pans' },
]

const MODIFIERS: { id: Modifiers; label: string }[] = [
  { id: 'baseline', label: '⇧/⌘ add' },
  { id: 'full', label: '⇧ add ⌥ cut ⌘ links' },
]

const LEFT_HELP: Record<LeftDrag, string> = {
  box: 'Drag empty canvas for a box. A card joins once the box covers a quarter of it each way.',
  sweep: 'Hover to see the brush’s reach, then drag to paint cards in. Scroll while dragging to resize the brush.',
  magnet: 'Drag and the cards within reach of the pointer are picked; move away and they drop out. Scroll while dragging to resize.',
  gather: 'Hover a card to see its linked cards. Press it, scroll for more hops, release to select, or drag to carry them. ✕ leaves one behind.',
}

const RIGHT_HELP: Record<RightDrag, string> = {
  menu: 'Pan with Space-drag, the middle button, or scrolling. Right click opens the menu on press.',
  pan: 'Right-drag pans. A right click that moves less than 5 px opens the menu on release.',
}

const MODIFIER_HELP: Record<Modifiers, string> = {
  baseline: '⇧ or ⌘ adds to the selection.',
  full: 'Hold mid-gesture: ⇧ adds, ⌥ takes away, ⌘ also picks up each hit’s linked cards.',
}

function Segmented<T extends string>({
  label,
  options,
  value,
  change,
}: {
  label: string
  options: { id: T; label: string }[]
  value: T
  change: (id: T) => void
}) {
  return (
    <div className="spike-row">
      <span className="spike-label">{label}</span>
      <div className="spike-segmented" role="radiogroup" aria-label={label}>
        {options.map((option) => (
          <button
            key={option.id}
            type="button"
            role="radio"
            aria-checked={value === option.id}
            className={value === option.id ? 'current' : undefined}
            onClick={() => change(option.id)}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  )
}

/** The gesture switcher, the tasks with their timings, and click paths around the board. */
export function SpikePanel({ gesture, setGesture, run, results, now, startTask, goTo, undo, reset }: Props) {
  const current = presetOf(gesture)

  return (
    <aside className="spike-panel panel" onPointerDown={(event) => event.stopPropagation()}>
      <h2>Gesture</h2>
      <div className="spike-presets">
        {PRESETS.map((preset) => (
          <button
            key={preset.id}
            type="button"
            className={current?.id === preset.id ? 'current' : undefined}
            onClick={() => setGesture(preset.gesture)}
          >
            <kbd>{preset.key}</kbd> {preset.label}
          </button>
        ))}
      </div>
      <Segmented label="Left drag" options={LEFT_DRAGS} value={gesture.leftDrag} change={(leftDrag) => setGesture({ ...gesture, leftDrag })} />
      <Segmented label="Right drag" options={RIGHT_DRAGS} value={gesture.rightDrag} change={(rightDrag) => setGesture({ ...gesture, rightDrag })} />
      <Segmented label="Keys" options={MODIFIERS} value={gesture.modifiers} change={(modifiers) => setGesture({ ...gesture, modifiers })} />
      <ul className="spike-help">
        <li>{LEFT_HELP[gesture.leftDrag]}</li>
        <li>{RIGHT_HELP[gesture.rightDrag]}</li>
        <li>{MODIFIER_HELP[gesture.modifiers]}</li>
      </ul>

      <h2>Tasks</h2>
      <ol className="spike-tasks">
        {TASKS.map((task) => {
          const active = run?.task === task.id

          return (
            <li key={task.id} className={active ? 'current' : undefined}>
              <button type="button" onClick={() => startTask(task.id)}>
                {active ? 'Restart' : 'Start'}
              </button>
              <span>{task.label}</span>
              {active && (
                <>
                  <p>{task.hint}</p>
                  <p className="spike-timer">
                    {run.seconds === undefined ? `${((now - run.startedAt) / 1000).toFixed(1)} s` : `Done in ${run.seconds.toFixed(1)} s ✓`} ·{' '}
                    {run.undos} undo · {run.cancels} cancel
                  </p>
                </>
              )}
            </li>
          )
        })}
      </ol>
      {results.length > 0 && (
        <table className="spike-results">
          <thead>
            <tr>
              <th>Task</th>
              <th>Gesture</th>
              <th>Time</th>
              <th>Undo</th>
              <th>Cancel</th>
            </tr>
          </thead>
          <tbody>
            {results.map((result, i) => (
              <tr key={i}>
                <td>{TASKS.find((task) => task.id === result.task)?.label}</td>
                <td>{result.preset}</td>
                <td>{result.seconds?.toFixed(1)} s</td>
                <td>{result.undos}</td>
                <td>{result.cancels}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <h2>Go to</h2>
      <div className="spike-presets">
        {DESTINATIONS.map((destination) => (
          <button key={destination.area} type="button" onClick={() => goTo(destination.area)}>
            {destination.label}
          </button>
        ))}
      </div>
      <div className="spike-presets">
        <button type="button" onClick={undo}>
          <kbd>⌘Z</kbd> Undo
        </button>
        <button type="button" onClick={reset}>
          Reset board
        </button>
      </div>
      <p className="spike-keys-help">
        Keys: Tab through cards, ↵ select, ⇧↵ toggle, L add linked cards, arrows move the selection, D deal out, F frame, Esc cancel or clear.
      </p>
    </aside>
  )
}
