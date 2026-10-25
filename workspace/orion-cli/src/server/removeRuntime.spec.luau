local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local fileNames = require("@root/fileNames")
local readRuntime = require("@root/server/readRuntime")
local removeRuntime = require("@root/server/removeRuntime")
local testing = require("@root/testing")
local writeRuntime = require("@root/server/writeRuntime")

test.case("removeRuntime keeps a newer server record", function(assert)
	local root = testing.directory("runtime-remove")
	local runtime: readRuntime.Runtime = {
		pid = 123,
		url = "http://127.0.0.1:5198",
		canvas = "default",
		dataFolder = root,
		startedAt = "2026-10-07T00:00:00Z",
	}
	writeRuntime(root, runtime)
	local older = table.clone(runtime)
	runtime.startedAt = "2026-10-07T00:01:00Z"
	writeRuntime(root, runtime)
	removeRuntime(root, older)
	assert.eq(fs.exists(path.join(root, fileNames.runtime)), true)
	local previousWorkspace = table.clone(runtime)
	runtime.canvas = "ideas"
	writeRuntime(root, runtime)
	removeRuntime(root, previousWorkspace)
	assert.eq(fs.exists(path.join(root, fileNames.runtime)), true)
	removeRuntime(root, runtime)
	assert.eq(fs.exists(path.join(root, fileNames.runtime)), false)
end)
