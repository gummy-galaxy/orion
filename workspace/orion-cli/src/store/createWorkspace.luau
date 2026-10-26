local fs = require("@std/fs")

local createEmptyDoc = require("@root/store/createEmptyDoc")
local deriveWorkspaceName = require("@root/deriveWorkspaceName")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local getWorkspaces = require("@root/store/getWorkspaces")
local isValidWorkspace = require("@root/store/isValidWorkspace")
local storeTypes = require("@root/store/types")
local writeDoc = require("@root/store/writeDoc")
local writeWorkspaces = require("@root/store/writeWorkspaces")

type WorkspaceList = storeTypes.WorkspaceList

-- Without a name, the label names the workspace. An explicit name must be a
-- lowercase slug.
local function createWorkspace(root: string, name: string?, label: string?): WorkspaceList
	assert(label == nil or label:match("%S"), "label must be nonempty")
	assert(name or label, "give a name or a label")
	local workspaceName = name or deriveWorkspaceName(label :: string)
	assert(isValidWorkspace(workspaceName), `invalid canvas name: {workspaceName}`)
	local list = getWorkspaces(root)

	for _, workspace in list.workspaces do
		assert(workspace.name ~= workspaceName, `canvas already exists: {workspaceName}`)
	end

	local dir = getWorkspaceDir(root, workspaceName)
	assert(not fs.exists(dir), `canvas folder already exists: {dir}`)

	writeDoc(dir, createEmptyDoc())
	table.insert(list.workspaces, { name = workspaceName, label = label or workspaceName })
	writeWorkspaces(root, list)

	return list
end

return createWorkspace
