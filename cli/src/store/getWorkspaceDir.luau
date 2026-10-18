local path = require("@std/path")

local isValidWorkspace = require("@root/store/isValidWorkspace")

-- The default workspace is the data root itself. Every other one has its own folder under it.
local function getWorkspaceDir(root: string, name: string): string
	assert(isValidWorkspace(name), `invalid canvas name: {name}`)
	return if name == "default" then root else tostring(path.join(root, "canvases", name))
end

return getWorkspaceDir
