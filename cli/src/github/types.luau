export type CheckCounts = { total: number, finished: number, failed: number }

-- One CI job on a pull request's head commit, by the name GitHub shows for it. `required` is whether the base branch's
-- rules require it to pass before merging.
export type CheckRun = { name: string, state: "failed" | "passed" | "pending" | "other", required: boolean }

-- A job that failed. An optional one failed where other jobs are required, so it doesn't count against the pull request.
export type FailedCheck = { name: string, optional: boolean }

export type PullState = {
	owner: string,
	name: string,
	number: number,
	state: string,
	baseRefName: string,
	headRefName: string,
	draft: boolean,
	reviewDecision: string?,
	reviewRequests: number,
	requestedReviewers: { string },
	title: string,
	url: string,
	author: string,
	updatedAt: string,
	additions: number,
	deletions: number,
	checks: string?,
	checkProgress: string?,
	checkCounts: CheckCounts?,
	-- Listed only for pull requests with a failing job, since finding them takes a second query.
	failedChecks: { FailedCheck }?,
	-- The jobs that passed, known for the same pull requests as failedChecks.
	passedChecks: { string }?,
	mergeable: string?,
	mergeState: string?,
	head: string?,
	branch: string?,
	body: string?,
	host: string?,
}

export type Ref = { owner: string, name: string, number: number, host: string? }
export type Change = {
	id: string,
	label: string,
	fromStatus: string,
	toStatus: string,
	fromWho: string?,
	toWho: string?,
	closed: boolean,
}
export type StackLink = { from: string, to: string }
export type Attachment = { id: string, pull: string }
export type Report = {
	changes: { Change },
	missing: { string },
	added: { string },
	attached: { Attachment },
	linked: { StackLink },
	unlinked: { StackLink },
	checked: number,
}
export type Fetched = {
	pulls: { [string]: PullState },
	authored: { PullState },
	viewer: string,
	discover: boolean,
}
export type IssueState = { owner: string, name: string, number: number, title: string, url: string, host: string? }

return table.freeze({})
