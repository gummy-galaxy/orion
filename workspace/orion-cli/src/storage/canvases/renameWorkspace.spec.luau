local test = require("@std/test")

local createWorkspace = require("@root/storage/canvases/createWorkspace")
local getWorkspaces = require("@root/storage/canvases/getWorkspaces")
local renameWorkspace = require("@root/storage/canvases/renameWorkspace")
local testing = require("@root/testing")

test.case("renameWorkspace changes only the label", function(assert)
	local root = testing.directory("rename")
	createWorkspace(root, "work", nil)
	renameWorkspace(root, "work", "Day job")

	local list = getWorkspaces(root)
	assert.eq(list.workspaces[2].name, "work")
	assert.eq(list.workspaces[2].label, "Day job")
	assert.throwsWith("label must be nonempty", function()
		renameWorkspace(root, "work", " ")
	end)
end)
