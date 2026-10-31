local test = require("@std/test")

local createWorkspace = require("@root/storage/canvases/createWorkspace")
local getWorkspaces = require("@root/storage/canvases/getWorkspaces")
local testing = require("@root/testing")
local useWorkspace = require("@root/storage/canvases/useWorkspace")

test.case("useWorkspace makes a listed workspace the active one", function(assert)
	local root = testing.directory("use")
	createWorkspace(root, "work", nil)
	useWorkspace(root, "work")
	assert.eq(getWorkspaces(root).active, "work")

	assert.throwsWith("unknown canvas: gone", function()
		useWorkspace(root, "gone")
	end)
end)
