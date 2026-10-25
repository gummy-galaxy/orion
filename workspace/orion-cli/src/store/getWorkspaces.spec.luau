local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local getWorkspaces = require("@root/store/getWorkspaces")
local testing = require("@root/testing")

test.case("without a list file there's only the default workspace", function(assert)
	local list = getWorkspaces(testing.directory("no-list"))
	assert.eq(list.active, "default")
	assert.eq(#list.workspaces, 1)
	assert.eq(list.workspaces[1].label, "Default")
	assert.eq(#list.archived, 0)
end)

test.case("getWorkspaces reads labels, archived workspaces, and the active one", function(assert)
	local root = testing.directory("list")
	fs.createDirectory(root, { makeParents = true })
	fs.writeStringToFile(
		path.join(root, "canvases.json"),
		[[{"active":"work","canvases":[{"name":"default","label":"Home"},{"name":"work","label":"Work"},{"name":"work","label":"Again"}],"archived":[{"name":"old","label":"Old"}]}]]
	)

	local list = getWorkspaces(root)
	assert.eq(list.active, "work")
	assert.eq(#list.workspaces, 2)
	assert.eq(list.workspaces[1].label, "Home")
	assert.eq(list.workspaces[2].label, "Work")
	assert.eq(list.archived[1].name, "old")
end)

test.case("getWorkspaces refuses a list that names a workspace twice or an unknown active one", function(assert)
	local root = testing.directory("bad-list")
	local file = path.join(root, "canvases.json")
	fs.createDirectory(root, { makeParents = true })

	fs.writeStringToFile(
		file,
		[[{"canvases":[{"name":"old","label":"Old"}],"archived":[{"name":"old","label":"Old"}]}]]
	)
	assert.throws(function()
		getWorkspaces(root)
	end)

	fs.writeStringToFile(file, [[{"active":"gone","canvases":[]}]])
	assert.throwsWith("unknown canvas: gone", function()
		getWorkspaces(root)
	end)
end)
