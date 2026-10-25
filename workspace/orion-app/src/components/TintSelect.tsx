import { TINTS, type Tint } from '../model'

/** Picks a group's or component's tint. Leaving it unset takes the nearest group's. */
export function TintSelect({ id, value, inherit, change }: { id: string; value?: Tint; inherit: string; change: (tint: Tint | undefined) => void }) {
  return (
    <select id={id} value={value ?? ''} onChange={(event) => change((event.target.value || undefined) as Tint | undefined)}>
      <option value="">{inherit}</option>
      {TINTS.map((tint) => (
        <option key={tint} value={tint}>
          {tint[0].toUpperCase() + tint.slice(1)}
        </option>
      ))}
    </select>
  )
}
