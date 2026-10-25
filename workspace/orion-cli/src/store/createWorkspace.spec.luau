local fs = require("@std/fs")
local test = require("@std/test")

local createWorkspace = require("@root/store/createWorkspace")
local getDocPath = require("@root/store/getDocPath")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local getWorkspaces = require("@root/store/getWorkspaces")
local testing = require("@root/testing")

test.case("createWorkspace lists the workspace and writes its empty data file", function(assert)
	local root = testing.directory("create")
	local list = createWorkspace(root, nil, "Focus areas")

	assert.eq(list.workspaces[2].name, "focus-areas")
	assert.eq(list.workspaces[2].label, "Focus areas")
	assert.eq(getWorkspaces(root).workspaces[2].name, "focus-areas")
	assert.eq(fs.exists(getDocPath(getWorkspaceDir(root, "focus-areas"))), true)
end)

test.case("createWorkspace refuses a name that's taken", function(assert)
	local root = testing.directory("create-taken")
	createWorkspace(root, "work", nil)

	assert.throwsWith("canvas already exists: work", function()
		createWorkspace(root, "work", "Work")
	end)
end)
