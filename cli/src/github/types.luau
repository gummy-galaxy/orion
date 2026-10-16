export type CheckCounts = { total: number, finished: number, failed: number }

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
	failures: { string },
}
-- Pull requests fetched by key. `checked` holds every key a successful query covered, so a key that's checked but
-- missing from `pulls` wasn't found, and an unchecked one wasn't asked for or failed.
export type PullResult = { pulls: { [string]: PullState }, checked: { [string]: boolean }, failures: { string } }
export type Fetched = {
	pulls: { [string]: PullState },
	checked: { [string]: boolean },
	authored: { PullState },
	viewer: string,
	discover: boolean,
	failures: { string },
}
export type IssueState = { owner: string, name: string, number: number, title: string, url: string, host: string? }

return table.freeze({})
