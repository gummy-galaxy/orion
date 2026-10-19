local json = require("@std/json")

export type Workspace = { name: string, label: string }
export type WorkspaceList = { active: string, workspaces: { Workspace }, archived: { Workspace } }
export type Backup = { revision: number, time: string, size: number, file: string }

-- What a node or link file keeps beside the entry itself: its order key, and when each of its fields last changed.
export type StoredEntry = { order: string?, changedAt: json.Object? }

-- A canvas folder as one read saw it. `files` maps each path under the folder, such as `nodes/a.json`, to its
-- text, `document` joins them into the shape a whole canvas encodes to, and `entries` keeps what each node and link
-- file stored beside its entry, by path.
export type CanvasSnapshot = {
	files: { [string]: string },
	document: json.Object,
	entries: { [string]: StoredEntry },
}

return nil
