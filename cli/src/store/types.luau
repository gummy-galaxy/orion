local json = require("@std/json")

export type Workspace = { name: string, label: string }
export type WorkspaceList = { active: string, workspaces: { Workspace }, archived: { Workspace } }
export type Backup = { revision: number, time: string, size: number, file: string }

-- A canvas folder as one read saw it. `document` joins its files into the shape a whole canvas encodes to, and
-- `files`, when the read asked for them, maps each path under the folder, such as `nodes/a.json`, to its text.
export type CanvasSnapshot = { files: { [string]: string }?, document: json.Object }

return nil
