local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local ensureDirectory = require("@root/platform/ensureDirectory")
local testing = require("@root/testing")

test.case("ensureDirectory creates a folder and its parents", function(assert)
	local dir = path.join(testing.directory("ensure-new"), "nested", "deeper")
	ensureDirectory(dir)

	assert.eq(fs.exists(dir), true)
end)

test.case("ensureDirectory leaves an existing folder and its contents alone", function(assert)
	local dir = testing.directory("ensure-existing")
	fs.createDirectory(dir, { makeParents = true })
	fs.writeStringToFile(path.join(dir, "kept"), "kept")
	ensureDirectory(dir)

	assert.eq(fs.readFileToString(path.join(dir, "kept")), "kept")
end)

test.case("ensureDirectory fails when a file is in the way", function(assert)
	local root = testing.directory("ensure-blocked")
	fs.createDirectory(root, { makeParents = true })
	fs.writeStringToFile(path.join(root, "file"), "")

	assert.throws(function()
		ensureDirectory(path.join(root, "file", "child"))
	end)
end)
