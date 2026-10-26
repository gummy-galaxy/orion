local json = require("@std/json")

export type CommandResult = {
	ok: boolean,
	exitCode: number,
	stdout: string,
	stderr: string,
}

export type CommandRunner = ({ string }, string?) -> CommandResult

-- A failure a script can act on, which --json prints as the error's code.
export type ErrorCode = "revision-conflict" | "missing-item" | "ambiguous-selector"

export type Position = { x: number, y: number }

export type Ref = {
	source: string,
	kind: string,
	-- The readable name for the ref, such as owner/name#12, which can change
	-- when what it names moves.
	key: string,
	-- The source's stable identity for the ref, which survives a rename or
	-- move. Adapters choose its form, and a ref has none until its source has
	-- been read.
	id: string?,
	url: string?,
	status: string?,
	isDone: boolean?,
	updatedAt: string?,
	-- What the source said, in its own terms. Only its adapter reads it.
	details: json.Object?,

	-- Source-neutral facts the adapter reads from details, which the app shows
	-- as they are. When the adapter last read the source.
	checkedAt: string?,
	-- The source's word for the ref's state, with the source's name, such as
	-- "Approved on GitHub".
	stateLabel: string?,
	-- How close open work is to landing: conflict, failing, running, waiting,
	-- passing, or mergeable.
	readiness: string?,
	-- The ref's checks: a state of passing, failing, or pending, and while the
	-- work is open, whether they're running or waiting and how many have
	-- finished and failed out of the total.
	checks: json.Object?,
	changesRequested: boolean?,
	author: string?,
	isMine: boolean?,
	isReviewRequested: boolean?,
	additions: number?,
	deletions: number?,
	-- The revision the facts describe, which an action taken from them, such as
	-- a merge, must still match.
	head: string?,
}

-- Mirrors a node as the app saves it. `data` stays raw JSON so fields the app
-- adds survive a CLI write.
export type Item = {
	id: string,
	type: string,
	-- Where the node's first placement puts it, and the group that holds it
	-- there. Changing them moves that placement when the canvas is written.
	position: Position,
	parentId: string?,
	-- The id of that placement. A node a change just added has none until the
	-- canvas is written, which places it.
	placement: string?,
	-- Set on a node with no placement, which isn't on the canvas anywhere. Its
	-- position and group mean nothing until a change moves it, which places it.
	unplaced: boolean?,
	width: number?,
	height: number?,
	data: json.Object,
}

-- One appearance of a node on the canvas: where it sits, and the group that
-- holds it there. A node can have any number of placements, or none, and none
-- of them is its home.
export type Placement = {
	id: string,
	node: string,
	parentId: string?,
	position: Position,
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
	browse: string?,
}

-- A CI job whose failures cards leave out, across every card in its repository.
-- `untilTime` ends it at a UTC time; without one it lasts on each card until
-- the job next passes there, and `passed` lists the cards where it has.
export type CheckSnooze = { repo: string, name: string, untilTime: string?, at: string, passed: { string } }

-- A card's pull request facts with its snoozed jobs left out. `snoozed` lists
-- those jobs, with when each timed snooze ends, and `wakesAt` is the soonest of
-- those times, when the facts change again.
export type SnoozedFacts = {
	readiness: string?,
	checks: json.Object?,
	snoozed: { { name: string, untilTime: string? } },
	wakesAt: string?,
}

export type Doc = {
	version: number,
	revision: number,
	-- cover, background, and header style the canvas itself: an image asset id,
	-- a color, token name, or asset id, and Markdown.
	settings: {
		sources: { Source },
		cover: string?,
		background: string?,
		header: string?,
		checkSnoozes: { CheckSnooze },
	},
	nodes: { Item },
	links: { Link },
	-- Every placement, grouped by node in the nodes' order. A write brings the
	-- first one of each node in line with the node's position and group.
	placements: { Placement },
	github: json.Object?,
	suggestions: json.Object?,
	-- What this machine last heard from GitHub about each repository its refs
	-- name, by repository id: its current owner/name and when that was checked.
	-- A cache, rebuilt from GitHub's answers.
	repositories: json.Object?,
	raw: json.Object?,
}

-- A ref resolved from --ref, with the repository it belongs to when it names
-- one.
export type ResolvedRef = {
	ref: Ref,
	repo: string?,
}

-- Who wrote a log entry: the person running the CLI, or an agent they named.
export type LogAuthor = { kind: "person" | "agent", name: string }

-- What a log entry is attached to. Cards are the only kind so far; pull
-- requests and issues join later.
export type LogTarget = { kind: "card", id: string }

-- One line of the canvas log. Entries are only ever appended, so a mistake is
-- corrected by a new entry.
export type LogEntry = {
	id: string,
	text: string,
	time: string,
	author: LogAuthor,
	targets: { LogTarget },
}

-- What the app has open and selected, as it last reported.
export type Focus = {
	open: string?,
	selected: { string },
	updatedAt: string?,
}

return {}
