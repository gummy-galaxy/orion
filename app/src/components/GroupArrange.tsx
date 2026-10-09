import type { Arrange, ClusterData } from '../model'

export function GroupArrange({ data, change }: { data: ClusterData; change: (patch: Pick<ClusterData, 'arrange'>) => void }) {
  const pick = (next: Arrange) => change({ arrange: next === 'auto' ? undefined : next })

  return (
    <div>
      <label htmlFor="g-arrange">Arrange</label>
      <select id="g-arrange" value={data.arrange ?? 'auto'} onChange={(event) => pick(event.target.value as Arrange)}>
        <option value="auto">Automatic</option>
        <option value="hand">Hand</option>
        <option value="custom">Custom</option>
      </select>
    </div>
  )
}
