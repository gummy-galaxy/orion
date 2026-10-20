local json = require("@std/json")

export type Workspace = { name: string, label: string }
export type WorkspaceList = { active: string, workspaces: { Workspace }, archived: { Workspace } }
export type Backup = { revision: number, time: string, size: number, file: string }

-- What a node or link file keeps beside the entry itself: its order key, and when each of its fields last changed.
export type StoredEntry = { order: string?, changedAt: json.Object? }

-- A canvas folder as one read saw it. `document` joins its files into the shape a whole canvas encodes to. When
-- the read asked for them, `files` maps each path under the folder, such as `nodes/a.json`, to its text, and
-- `entries` keeps what each node and link file stored beside its entry, by path.
export type CanvasSnapshot = {
	files: { [string]: string }?,
	document: json.Object,
	entries: { [string]: StoredEntry }?,
}

-- The files one write puts in place, keyed by path under the canvas folder, and the paths it removes. The journal
-- keeps it until every file has landed.
export type CanvasWrite = { writes: { [string]: string }, removes: { string } }

return nil
