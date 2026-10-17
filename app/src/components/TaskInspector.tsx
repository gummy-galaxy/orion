import { useAtomValue } from 'jotai'
import { ChecksIcon } from './ChecksIcon'
import { LinkList } from './LinkList'
import { NoteBody } from './NoteBody'
import { StatusIcon } from './StatusIcon'
import { Timeline } from './Timeline'
import { useCardLog } from '../useCardLog'
import { workspaceAtom } from '../state'
import type { Work } from '../derive'
import {
  READINESS_LABEL,
  STATUS_LABEL,
  editPullRef,
  getCheckCountsLabel,
  getItemKind,
  getPullReadiness,
  getPullRef,
  getPullRequestNumber,
  githubSummary,
  isTask,
  relativeTime,
  type AppNode,
  type GithubSnapshot,
  type Link,
  type PullDetails,
  type Status,
  type TaskData,
  type Who,
} from '../model'

export function TaskInspector({
  node,
  work,
  map,
  github,
  update,
  jumpTo,
  connections = true,
  focus = false,
  doneEditing,
  links,
  addLink,
  removeLink,
  flipLink,
}: {
  node: AppNode
  work: Work
  map: Map<string, AppNode>
  github: GithubSnapshot | null
  update: (id: string, patch: Partial<TaskData>) => void
  jumpTo: (id: string) => void
  /** Focus view draws connections beside the inspector. */
  connections?: boolean
  /** Focuses the title, for a card that was just added. */
  focus?: boolean
  doneEditing?: () => void
  links: Link[]
  addLink: (from: string, to: string, kind: Link['kind']) => void
  removeLink: (id: string) => void
  flipLink: (id: string) => void
}) {
  const data = node.data as TaskData
  const workspace = useAtomValue(workspaceAtom)
  const log = useCardLog(workspace, node.id)
  const status = work.status.get(node.id) ?? 'ready'
  const leverage = work.leverage.get(node.id) ?? 0
  // Every link a card carries to its pull requests and issues, so each one opens from the header.
  const refLinks = (data.refs ?? []).filter((ref) => ref.url)
  const pullRef = getPullRef(data)
  const pullDetails = pullRef?.details as PullDetails | undefined
  const readiness = getPullReadiness(pullDetails)
  const checkCountsLabel = readiness && pullDetails?.checkCounts && getCheckCountsLabel(pullDetails.checkCounts)
  const linked = new Set(
    [...map.values()].filter(isTask).flatMap((node) => {
      const ref = getPullRef(node.data)

      return ref ? [ref.key.toLowerCase()] : []
    }),
  )
  const suggestions = pullRef
    ? []
    : (github?.unplaced ?? [])
        .filter((pullRequest) => !linked.has(`${pullRequest.repo}#${pullRequest.number}`.toLowerCase()))
        .flatMap((pullRequest) =>
          pullRequest.matches.filter((match) => match.id === node.id).map((match) => ({ pr: pullRequest, score: match.score })),
        )
        .sort((a, b) => b.score - a.score)

  return (
    <div className="insp task-insp">
      {/* The title leads, with the card's pull requests and issues beside it. */}
      <div className="insp-title">
        <input
          id="t-label"
          className="title-input"
          aria-label="Title"
          value={data.label}
          autoFocus={focus}
          onBlur={doneEditing}
          onKeyDown={(event) => event.key === 'Enter' && event.currentTarget.blur()}
          onChange={(event) => update(node.id, { label: event.target.value })}
        />
        {refLinks.length > 0 && (
          <div className="ref-links">
            {refLinks.map((ref) => (
              <a
                key={`${ref.source}:${ref.kind}:${ref.key}`}
                className="pr-link"
                href={ref.url}
                target="_blank"
                rel="noreferrer"
                title={ref.kind === 'pull' ? 'Open pull request' : ref.kind === 'issue' ? 'Open issue' : `Open ${ref.key}`}
              >
                {ref.key} ↗
              </a>
            ))}
          </div>
        )}
      </div>

      <section className="insp-section" aria-label="Status">
        <div className="grid2">
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
        <p className="facts">
          Shown as <StatusIcon status={status} />
          <b>{STATUS_LABEL[status]}</b>
          {leverage > 0 && <> · unblocks {leverage}</>}
        </p>
      </section>

      <section className="insp-section">
        <h3 className="insp-heading">Notes</h3>
        <NoteBody id="t-note" note={data.note} change={(note) => update(node.id, { note })} />
      </section>

      <Timeline entries={log} />

      <section className="insp-section">
        <h3 className="insp-heading">Pull request</h3>
        {pullDetails && (
          <div className="github-details">
            <p className="facts">{githubSummary(pullDetails)}</p>
            <p className="facts">
              {readiness && (
                <>
                  <ChecksIcon readiness={readiness} />
                  {READINESS_LABEL[readiness]}
                  {checkCountsLabel && `, ${checkCountsLabel}`} ·{' '}
                </>
              )}
              {typeof pullDetails.additions === 'number' && (
                <>
                  +{pullDetails.additions} −{pullDetails.deletions} · updated {relativeTime(pullDetails.updatedAt)}
                </>
              )}
            </p>
            {pullDetails.author && !pullDetails.mine && <p className="facts">By {pullDetails.author}</p>}
            {pullDetails.requestedFromYou && <p className="facts review-requested">Your review is requested</p>}
          </div>
        )}
        <div className="grid2">
          <div>
            <label htmlFor="t-repo">Repository</label>
            <input
              id="t-repo"
              value={data.repo ?? ''}
              placeholder="owner/name"
              onChange={(event) => {
                const repo = event.target.value || undefined

                update(node.id, editPullRef(data, repo, getPullRequestNumber(pullRef)))
              }}
            />
          </div>
          <div>
            <label htmlFor="t-pr">Pull request</label>
            <input
              id="t-pr"
              inputMode="numeric"
              value={getPullRequestNumber(pullRef) ?? ''}
              placeholder="Not opened"
              disabled={!data.repo?.trim()}
              onChange={(event) => {
                const number = Number(event.target.value.replace(/^#/, ''))
                const pullRequest = Number.isInteger(number) && number > 0 ? number : undefined

                update(node.id, editPullRef(data, data.repo, pullRequest))
              }}
            />
          </div>
        </div>
        <label className="gate-toggle">
          <input
            type="checkbox"
            checked={data.itemKind === 'gate'}
            onChange={(event) => update(node.id, { itemKind: event.target.checked ? 'gate' : getItemKind({ ...data, itemKind: 'step' }) })}
          />
          Gate: done once everything it waits on is
        </label>
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
                <button type="button" className="btn" onClick={() => update(node.id, editPullRef(data, pullRequest.repo, pullRequest.number))}>
                  Link
                </button>
              </div>
            ))}
          </div>
        )}
      </section>

      {connections && (
        <section className="insp-section">
          <h3 className="insp-heading">Relationships</h3>
          <LinkList
            node={node}
            work={work}
            nodeMap={map}
            links={links}
            jumpTo={jumpTo}
            addLink={addLink}
            removeLink={removeLink}
            flipLink={flipLink}
          />
        </section>
      )}
    </div>
  )
}
