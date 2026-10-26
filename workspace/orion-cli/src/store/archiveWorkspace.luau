local getWorkspaces = require("@root/store/getWorkspaces")
local isValidWorkspace = require("@root/store/isValidWorkspace")
local storeTypes = require("@root/store/types")
local writeWorkspaces = require("@root/store/writeWorkspaces")

type WorkspaceList = storeTypes.WorkspaceList

-- Takes a workspace off the list without touching its folder. The default
-- workspace is the data root itself and is always listed, so it can't be
-- archived, and neither can the one in use.
local function archiveWorkspace(root: string, name: string, inUse: string): WorkspaceList
	assert(isValidWorkspace(name), `invalid canvas name: {name}`)
	assert(name ~= "default", "the default canvas can't be archived")
	local list = getWorkspaces(root)
	assert(name ~= list.active and name ~= inUse, `can't archive the active canvas: {name}`)

	for _, workspace in list.archived do
		assert(workspace.name ~= name, `canvas already archived: {name}`)
	end

	for index, workspace in list.workspaces do
		if workspace.name == name then
			table.remove(list.workspaces, index)
			table.insert(list.archived, workspace)
			writeWorkspaces(root, list)
			return list
		end
	end

	error(`unknown canvas: {name}`)
end

return archiveWorkspace
