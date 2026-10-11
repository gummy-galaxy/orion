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
