local getWorkspaces = require("@root/storage/canvases/getWorkspaces")
local isValidWorkspace = require("@root/storage/canvases/isValidWorkspace")
local storeTypes = require("@root/storage/types")
local writeWorkspaces = require("@root/storage/canvases/writeWorkspaces")

type WorkspaceList = storeTypes.WorkspaceList

local function useWorkspace(root: string, name: string): WorkspaceList
	local list = getWorkspaces(root)
	assert(isValidWorkspace(name), `invalid canvas name: {name}`)
	local isKnown = false

	for _, workspace in list.workspaces do
		isKnown = isKnown or workspace.name == name
	end

	assert(isKnown, `unknown canvas: {name}`)
	list.active = name
	writeWorkspaces(root, list)

	return list
end

return useWorkspace
