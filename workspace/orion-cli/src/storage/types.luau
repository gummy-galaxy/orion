local json = require("@std/json")

export type Workspace = { name: string, label: string }
export type WorkspaceList = { active: string, workspaces: { Workspace }, archived: { Workspace } }
export type Backup = { revision: number, time: string, size: number, file: string }

-- Who made a revision: a CLI command, run directly or through an MCP tool, by
-- its path such as "link create". Writes from `orion server start`, for the app
-- and its refresh, have no writer and read as the app's.
export type Writer = { by: "cli" | "mcp", command: string }

-- One line of a canvas's revision log: a revision, when it was written in
-- RFC 3339 UTC, and who wrote it.
export type RevisionEntry = { revision: number, time: string, by: string, command: string? }

-- What a node or link file keeps beside the entry itself: its order key, and
-- when each of its fields last changed.
export type StoredEntry = { order: string?, changedAt: json.Object? }

-- A canvas folder as one read saw it. `document` joins its files into the shape
-- a whole canvas encodes to. When the read asked for them, `files` maps each
-- path under the folder, such as `nodes/a.json`, to its text, and `entries`
-- keeps what each node and link file stored beside its entry, by path.
-- `problems` describes files that didn't parse and how the read worked around
-- them. `fingerprint`, from the index, changes whenever any file's text does.
export type CanvasSnapshot = {
	files: { [string]: string }?,
	document: json.Object,
	entries: { [string]: StoredEntry }?,
	problems: { string }?,
	fingerprint: string?,
}

-- The files one write puts in place, keyed by path under the canvas folder, and
-- the paths it removes. The journal keeps it until every file has landed.
export type CanvasWrite = { writes: { [string]: string }, removes: { string } }

return nil
