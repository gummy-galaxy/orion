local getWorkspaces = require("@root/store/getWorkspaces")
local isValidWorkspace = require("@root/store/isValidWorkspace")
local storeTypes = require("@root/store/types")
local writeWorkspaces = require("@root/store/writeWorkspaces")

type WorkspaceList = storeTypes.WorkspaceList

local function renameWorkspace(root: string, name: string, label: string): WorkspaceList
	assert(isValidWorkspace(name), `invalid canvas name: {name}`)
	assert(label:match("%S"), "label must be nonempty")
	local list = getWorkspaces(root)

	for _, workspace in list.workspaces do
		if workspace.name == name then
			workspace.label = label
			writeWorkspaces(root, list)
			return list
		end
	end

	error(`unknown canvas: {name}`)
end

return renameWorkspace
