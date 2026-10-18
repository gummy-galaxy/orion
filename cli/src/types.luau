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
	details: json.Object?,
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

-- A CI job whose failures cards leave out, across every card in its repository. `untilTime` ends it at a UTC time;
-- without one it lasts on each card until the job next passes there, and `passed` lists the cards where it has.
export type CheckSnooze = { repo: string, name: string, untilTime: string?, at: string, passed: { string } }

export type Doc = {
	version: number,
	revision: number,
	-- cover, background, and header style the canvas itself: an image asset id, a color, token name, or asset id, and Markdown.
	settings: {
		sources: { Source },
		cover: string?,
		background: string?,
		header: string?,
		checkSnoozes: { CheckSnooze },
	},
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

-- Who wrote a log entry: the person running the CLI, or an agent they named.
export type LogAuthor = { kind: "person" | "agent", name: string }

-- What a log entry is attached to. Cards are the only kind so far; pull requests and issues join later.
export type LogTarget = { kind: "card", id: string }

-- One line of the canvas log. Entries are only ever appended, so a mistake is corrected by a new entry.
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
