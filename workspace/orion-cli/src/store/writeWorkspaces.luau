local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local storeTypes = require("@root/store/types")

type WorkspaceList = storeTypes.WorkspaceList

local writeSequence = 0

-- Replaces the workspace list file in one move, so a reader never sees half of it.
local function writeWorkspaces(root: string, list: WorkspaceList)
	ensureDirectory(root)

	local entries: json.Array = {}

	for _, workspace in list.workspaces do
		table.insert(entries, json.object({ name = workspace.name, label = workspace.label }))
	end

	local value = json.object({ active = list.active, canvases = entries })

	if #list.archived > 0 then
		local archived: json.Array = {}

		for _, workspace in list.archived do
			table.insert(archived, json.object({ name = workspace.name, label = workspace.label }))
		end

		value.archived = archived
	end

	local file = tostring(path.join(root, fileNames.canvases))
	writeSequence += 1
	local temporary = `{file}.tmp.{process.pid()}.{writeSequence}`
	fs.writeStringToFile(temporary, json.serialize(value, true))
	fs.move(temporary, file)
end

return writeWorkspaces
