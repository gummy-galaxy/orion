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
