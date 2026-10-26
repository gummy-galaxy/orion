import { useState, type KeyboardEvent } from 'react'
import { useAtomValue } from 'jotai'
import { ChecksIcon } from './ChecksIcon'
import { CheckSnoozes } from './CheckSnoozes'
import { LinkList } from './LinkList'
import { NoteBody } from './NoteBody'
import { StatusIcon } from './StatusIcon'
import { getPullRepo } from '../getPullRepo'
import { withSnoozedFacts } from '../withSnoozedFacts'
import { Timeline } from './Timeline'
import { useCardLog } from '../useCardLog'
import type { SnoozedJob, Work } from '../derive'
import { workspaceAtom } from '../state'
import type { CardFields, SaveFields } from '../fields/types'
import {
  READINESS_LABEL,
  STATUS_CHOICES,
  STATUS_LABEL,
  WHO_CHOICES,
  getCheckCounts,
  getCheckCountsLabel,
  getPullRef,
  getPullRequestNumber,
  getRefSummary,
  isTask,
  relativeTime,
  type AppNode,
  type GithubSnapshot,
  type Link,
  type Status,
  type TaskData,
  type Who,
} from '../model'

// One empty list, so the snooze checkboxes can tell when the server answers a toggle on a card with none snoozed yet.
const NO_SNOOZED_JOBS: SnoozedJob[] = []

export function TaskInspector({
  node,
  work,
  map,
  github,
  update,
  saveFields,
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
  /** Saves fields the server works the kind and refs out from, and resolves once it answers. */
  saveFields: SaveFields
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
  const recorded = getPullRef(data)
  const snoozedFacts = work.pulls.get(node.id)
  const pullRef = recorded && withSnoozedFacts(recorded, snoozedFacts)
  const repo = pullRef ? getPullRepo(pullRef.key) : undefined
  const failures = pullRef?.checks?.failures ?? []
  const readiness = pullRef?.readiness
  const checkCounts = getCheckCounts(pullRef?.checks)
  const checkCountsLabel = readiness && checkCounts && getCheckCountsLabel(checkCounts)
  const summary = pullRef && getRefSummary(pullRef)
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
  // The repository and pull request show as typed until they save, which happens when either input loses focus.
  // The card takes its new kind and ref from the server's answer.
  const [draft, setDraft] = useState<{ repo: string; pullRequest: string } | null>(null)
  const [fieldError, setFieldError] = useState<string | null>(null)
  const savedPullRequest = getPullRequestNumber(pullRef)
  const shown = draft ?? { repo: data.repo ?? '', pullRequest: savedPullRequest ? String(savedPullRequest) : '' }

  const save = (fields: CardFields) => {
    setFieldError(null)
    void saveFields(node.id, fields).then((error) => {
      setFieldError(error)

      if (!error) setDraft(null)
    })
  }

  const saveDraft = () => {
    if (!draft) return

    const repository = draft.repo.trim()
    const number = Number(draft.pullRequest.trim().replace(/^#/, ''))
    const pullRequest = repository && Number.isInteger(number) && number > 0 ? number : undefined

    if (repository === (data.repo ?? '') && pullRequest === savedPullRequest) return setDraft(null)

    save({ repo: repository, pr: pullRequest ?? '' })
  }

  const blurOnEnter = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') event.currentTarget.blur()
  }

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
              {STATUS_CHOICES.map((choice) => (
                <option key={choice.value} value={choice.value}>
                  {choice.label}
                </option>
              ))}
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
              {WHO_CHOICES.map((choice) => (
                <option key={choice.value} value={choice.value}>
                  {choice.label}
                </option>
              ))}
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
        {pullRef && summary && (
          <div className="github-details">
            <p className="facts">{summary}</p>
            <p className="facts">
              {readiness && (
                <>
                  <ChecksIcon readiness={readiness} />
                  {READINESS_LABEL[readiness]}
                  {checkCountsLabel && `, ${checkCountsLabel}`} ·{' '}
                </>
              )}
              {typeof pullRef.additions === 'number' && (
                <>
                  +{pullRef.additions} −{pullRef.deletions}
                  {pullRef.updatedAt && <> · updated {relativeTime(pullRef.updatedAt)}</>}
                </>
              )}
            </p>
            {repo && readiness && failures.length ? (
              <CheckSnoozes repo={repo} failures={failures} snoozed={snoozedFacts?.snoozed ?? NO_SNOOZED_JOBS} />
            ) : null}
            {pullRef.author && !pullRef.isMine && <p className="facts">By {pullRef.author}</p>}
            {pullRef.isReviewRequested && <p className="facts review-requested">Your review is requested</p>}
          </div>
        )}
        <div className="grid2">
          <div>
            <label htmlFor="t-repo">Repository</label>
            <input
              id="t-repo"
              value={shown.repo}
              placeholder="owner/name"
              onChange={(event) => setDraft({ ...shown, repo: event.target.value })}
              onBlur={saveDraft}
              onKeyDown={blurOnEnter}
            />
          </div>
          <div>
            <label htmlFor="t-pr">Pull request</label>
            <input
              id="t-pr"
              inputMode="numeric"
              value={shown.pullRequest}
              placeholder="Not opened"
              disabled={!shown.repo.trim()}
              onChange={(event) => setDraft({ ...shown, pullRequest: event.target.value })}
              onBlur={saveDraft}
              onKeyDown={blurOnEnter}
            />
          </div>
        </div>
        {fieldError && (
          <p className="field-error" role="alert">
            {fieldError}
          </p>
        )}
        <label className="gate-toggle">
          <input type="checkbox" checked={data.type === 'gate'} onChange={(event) => save({ kind: event.target.checked ? 'gate' : 'step' })} />
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
                <button type="button" className="btn" onClick={() => save({ repo: pullRequest.repo, pr: pullRequest.number })}>
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
