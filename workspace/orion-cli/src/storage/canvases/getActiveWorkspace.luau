local getWorkspaces = require("@root/storage/canvases/getWorkspaces")
local isValidWorkspace = require("@root/storage/canvases/isValidWorkspace")
local migrateCanvasFiles = require("@root/storage/migrations/migrateCanvasFiles")
local migrateSourceCommands = require("@root/storage/migrations/migrateSourceCommands")
local migrateWorkspaces = require("@root/storage/migrations/migrateWorkspaces")

-- Every command resolves its canvas here first, so this is where an older data
-- folder moves to the canvas layout, its canvases to folders of files, and its
-- source commands out of those files. Remove at 0.1.0 with the rest of
-- `migrations/`.
local function getActiveWorkspace(root: string, requested: string?, configured: string?): string
	migrateWorkspaces(root)
	migrateCanvasFiles(root)
	migrateSourceCommands(root)

	local list = getWorkspaces(root)
	local name = requested or (if configured ~= "" then configured else nil) or list.active
	assert(isValidWorkspace(name), `invalid canvas name: {name}`)

	for _, workspace in list.workspaces do
		if workspace.name == name then
			return name
		end
	end

	error(`unknown canvas: {name}`)
end

return getActiveWorkspace
