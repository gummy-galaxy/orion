local fs = require("@std/fs")

local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local getWorkspaces = require("@root/storage/canvases/getWorkspaces")
local isValidWorkspace = require("@root/storage/canvases/isValidWorkspace")
local storeTypes = require("@root/storage/types")
local writeWorkspaces = require("@root/storage/canvases/writeWorkspaces")

type WorkspaceList = storeTypes.WorkspaceList

-- Puts an archived workspace back on the list. Its folder is still in place, so
-- it returns with its data.
local function restoreWorkspace(root: string, name: string): WorkspaceList
	assert(isValidWorkspace(name), `invalid canvas name: {name}`)
	local list = getWorkspaces(root)

	for index, workspace in list.archived do
		if workspace.name == name then
			local dir = getWorkspaceDir(root, name)
			assert(fs.exists(dir), `canvas folder is missing: {dir}`)
			table.remove(list.archived, index)
			table.insert(list.workspaces, workspace)
			writeWorkspaces(root, list)
			return list
		end
	end

	error(`unknown archived canvas: {name}`)
end

return restoreWorkspace
