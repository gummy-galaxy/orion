import { LinkList } from './LinkList'
import type { Work } from '../derive'
import {
  STATUS_LABEL,
  getItemKind,
  getTaskUrl,
  getTaskTag,
  githubSummary,
  isTask,
  relativeTime,
  type AppNode,
  type GithubSnapshot,
  type Link,
  type Status,
  type TaskData,
  type Who,
} from '../model'

export function TaskInspector({
  node,
  work,
  map,
  github,
  githubOwner,
  update,
  jumpTo,
  connections = true,
  links,
  addLink,
  removeLink,
  flipLink,
}: {
  node: AppNode
  work: Work
  map: Map<string, AppNode>
  github: GithubSnapshot | null
  githubOwner: string
  update: (id: string, patch: Partial<TaskData>) => void
  jumpTo: (id: string) => void
  /** Focus view draws connections beside the inspector. */
  connections?: boolean
  links: Link[]
  addLink: (from: string, to: string, kind: Link['kind']) => void
  removeLink: (id: string) => void
  flipLink: (id: string) => void
}) {
  const data = node.data as TaskData
  const status = work.status.get(node.id) ?? 'ready'
  const leverage = work.leverage.get(node.id) ?? 0
  const url = getTaskUrl(data, githubOwner)
  const linked = new Set(
    [...map.values()]
      .filter(isTask)
      .filter((node) => node.data.repo && node.data.pr)
      .map((node) => `${node.data.repo}#${node.data.pr}`),
  )
  const suggestions = data.pr
    ? []
    : (github?.unplaced ?? [])
        .filter((pullRequest) => !linked.has(`${pullRequest.repo}#${pullRequest.number}`))
        .flatMap((pullRequest) =>
          pullRequest.matches.filter((match) => match.id === node.id).map((match) => ({ pr: pullRequest, score: match.score })),
        )
        .sort((a, b) => b.score - a.score)

  return (
    <div className="insp">
      <label htmlFor="t-label">Title</label>
      <input id="t-label" value={data.label} onChange={(event) => update(node.id, { label: event.target.value })} />
      {url && (
        <a className="pr-link" href={url} target="_blank" rel="noreferrer">
          Open {getTaskTag(data)} ↗
        </a>
      )}
      {data.github && (
        <div className="github-details">
          <p className="facts">{githubSummary(data.github)}</p>
          <p className="facts">
            {data.github.checks && (
              <>
                <span className={`check-dot check-${data.github.checks.toLowerCase()}`} />
                {data.github.checks === 'SUCCESS'
                  ? 'Checks passing'
                  : ['FAILURE', 'ERROR'].includes(data.github.checks)
                    ? 'Checks failing'
                    : 'Checks pending'}{' '}
                ·{' '}
              </>
            )}
            {typeof data.github.additions === 'number' && (
              <>
                +{data.github.additions} −{data.github.deletions} · updated {relativeTime(data.github.updatedAt)}
              </>
            )}
          </p>
          {data.github.author && !data.github.mine && <p className="facts">By {data.github.author}</p>}
          {data.github.requestedFromYou && <p className="facts review-requested">Your review is requested</p>}
        </div>
      )}
      <label className="gate-toggle">
        <input
          type="checkbox"
          checked={data.itemKind === 'gate'}
          onChange={(event) => update(node.id, { itemKind: event.target.checked ? 'gate' : getItemKind({ ...data, itemKind: 'step' }) })}
        />
        Gate: done once everything it waits on is
      </label>
      <div className="grid2">
        <div>
          <label htmlFor="t-repo">Repository</label>
          <input
            id="t-repo"
            value={data.repo ?? ''}
            placeholder="None"
            onChange={(event) => {
              const repo = event.target.value.trim() || undefined

              update(node.id, { repo, itemKind: getItemKind({ ...data, repo }) })
            }}
          />
        </div>
        <div>
          <label htmlFor="t-pr">Pull request</label>
          <input
            id="t-pr"
            inputMode="numeric"
            value={data.pr ?? ''}
            placeholder="Not opened"
            onChange={(event) => {
              const number = Number(event.target.value.replace(/^#/, ''))
              const pullRequest = Number.isInteger(number) && number > 0 ? number : undefined

              update(node.id, { pr: pullRequest, itemKind: getItemKind({ ...data, pr: pullRequest }) })
            }}
          />
        </div>
        <div>
          <label htmlFor="t-status">Status</label>
          <select id="t-status" value={data.status} onChange={(event) => update(node.id, { status: event.target.value as Status })}>
            <option value="todo">To do</option>
            <option value="active">In progress</option>
            <option value="review">In review</option>
            <option value="blocked">Blocked</option>
            <option value="deferred">Deferred</option>
            <option value="done">Done</option>
          </select>
        </div>
        <div>
          <label htmlFor="t-who">Whose move</label>
          <select
            id="t-who"
            value={data.who ?? ''}
            onChange={(event) => update(node.id, { who: (event.target.value || undefined) as Who | undefined })}
          >
            <option value="">Not set</option>
            <option value="you">You</option>
            <option value="review">Reviewer</option>
            <option value="ci">CI</option>
          </select>
        </div>
      </div>
      {suggestions.length > 0 && (
        <div className="suggestions">
          <span className="label-text">Possible pull requests</span>
          {suggestions.map(({ pr: pullRequest, score }) => (
            <div className="suggestion" key={`${pullRequest.repo}#${pullRequest.number}`}>
              <div className="suggestion-copy">
                <a href={pullRequest.url} target="_blank" rel="noreferrer">
                  {pullRequest.title}
                </a>
                <span>
                  {pullRequest.repo}#{pullRequest.number} · {score >= 0.6 ? 'High' : score >= 0.35 ? 'Medium' : 'Low'} confidence
                </span>
              </div>
              <button
                type="button"
                className="btn"
                onClick={() =>
                  update(node.id, {
                    repo: pullRequest.repo,
                    pr: pullRequest.number,
                    itemKind: getItemKind({ ...data, repo: pullRequest.repo, pr: pullRequest.number }),
                  })
                }
              >
                Link
              </button>
            </div>
          ))}
        </div>
      )}
      <label htmlFor="t-note">Notes</label>
      <textarea id="t-note" rows={3} value={data.note ?? ''} onChange={(event) => update(node.id, { note: event.target.value || undefined })} />
      <p className="facts">
        Shown as <b>{STATUS_LABEL[status]}</b>
        {leverage > 0 && <> · unblocks {leverage}</>}
      </p>
      {connections && (
        <LinkList node={node} work={work} nodeMap={map} links={links} jumpTo={jumpTo} addLink={addLink} removeLink={removeLink} flipLink={flipLink} />
      )}
    </div>
  )
}
