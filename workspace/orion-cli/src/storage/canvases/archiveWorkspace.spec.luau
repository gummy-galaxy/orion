local test = require("@std/test")

local archiveWorkspace = require("@root/storage/canvases/archiveWorkspace")
local createWorkspace = require("@root/storage/canvases/createWorkspace")
local getWorkspaces = require("@root/storage/canvases/getWorkspaces")
local testing = require("@root/testing")

test.case("archiveWorkspace moves a workspace to the archived list", function(assert)
	local root = testing.directory("archive")
	createWorkspace(root, "work", nil)
	archiveWorkspace(root, "work", "default")

	local list = getWorkspaces(root)
	assert.eq(#list.workspaces, 1)
	assert.eq(list.archived[1].name, "work")
end)

test.case("archiveWorkspace refuses the default workspace and the one in use", function(assert)
	local root = testing.directory("archive-refused")
	createWorkspace(root, "work", nil)

	assert.throwsWith("the default canvas can't be archived", function()
		archiveWorkspace(root, "default", "work")
	end)
	assert.throwsWith("can't archive the active canvas: work", function()
		archiveWorkspace(root, "work", "work")
	end)
end)
