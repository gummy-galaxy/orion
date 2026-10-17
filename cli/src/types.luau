local json = require("@std/json")

export type CommandResult = {
	ok: boolean,
	exitCode: number,
	stdout: string,
	stderr: string,
}

export type CommandRunner = ({ string }, string?) -> CommandResult

export type Position = { x: number, y: number }

export type Ref = {
	source: string,
	kind: string,
	key: string,
	url: string?,
	status: string?,
	isDone: boolean?,
	updatedAt: string?,
	-- What the source said, in its own terms. Only its adapter reads it.
	details: json.Object?,

	-- Source-neutral facts the adapter reads from details, which the app shows as they are.
	-- When the adapter last read the source.
	checkedAt: string?,
	-- The source's word for the ref's state, with the source's name, such as "Approved on GitHub".
	stateLabel: string?,
	-- How close open work is to landing: conflict, failing, running, waiting, passing, or mergeable.
	readiness: string?,
	-- The ref's checks: a state of passing, failing, or pending, and while the work is open, whether they're running
	-- or waiting and how many have finished and failed out of the total.
	checks: json.Object?,
	changesRequested: boolean?,
	author: string?,
	isMine: boolean?,
	isReviewRequested: boolean?,
	additions: number?,
	deletions: number?,
	-- The revision the facts describe, which an action taken from them, such as a merge, must still match.
	head: string?,
}

-- Mirrors a node as the app saves it. `data` stays raw JSON so fields the app adds survive a CLI write.
export type Item = {
	id: string,
	type: string,
	position: Position,
	parentId: string?,
	width: number?,
	height: number?,
	data: json.Object,
}

export type Link = {
	id: string,
	from: string,
	to: string,
	kind: string,
	origin: string?,
	label: string?,
}

export type Source = {
	id: string,
	kind: string,
	host: string?,
	owners: { string }?,
	include: { string }?,
	exclude: { string }?,
	command: { string }?,
	browse: string?,
}

export type Doc = {
	version: number,
	revision: number,
	-- cover, background, and header style the canvas itself: an image asset id, a color, token name, or asset id, and Markdown.
	settings: { sources: { Source }, cover: string?, background: string?, header: string? },
	nodes: { Item },
	links: { Link },
	github: json.Object?,
	suggestions: json.Object?,
	raw: json.Object?,
}

-- A ref resolved from --ref, with the repository it belongs to when it names one.
export type ResolvedRef = {
	ref: Ref,
	repo: string?,
}

-- What the app has open and selected, as it last reported.
export type Focus = {
	open: string?,
	selected: { string },
	updatedAt: string?,
}

return {}
