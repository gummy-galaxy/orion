local json = require("@std/json")

export type CommandResult = {
	ok: boolean,
	exitCode: number,
	stdout: string,
	stderr: string,
}

export type CommandRunner = ({ string }) -> CommandResult

export type Position = { x: number, y: number }

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
}

export type Doc = {
	version: number,
	revision: number,
	settings: { githubOwner: string },
	nodes: { Item },
	links: { Link },
	github: json.Object?,
	raw: json.Object?,
}

return {}
